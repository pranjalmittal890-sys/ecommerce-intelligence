# Phase 3 — Data Profiling Summary

> Run [`sql/03_profiling/03_profiling_execution.sql`](../sql/03_profiling/03_profiling_execution.sql) section by section in BigQuery and paste results into the tables below.
> Prereq: Phase 0 complete (raw tables loaded into `olist_raw`).
> Status: **template — not yet run.** Fields marked `___` are placeholders for your actual numbers.

---

## 0. Warehouse sanity check

| Table | Expected row count | Actual row count | Match? |
|---|---|---|---|
| orders | ~99,441 | ___ | ☐ |
| customers | ~99,441 | ___ | ☐ |
| order_items | ~112,650 | ___ | ☐ |
| order_payments | ~103,886 | ___ | ☐ |
| order_reviews | ~99,224 | ___ | ☐ |
| products | ~32,951 | ___ | ☐ |
| sellers | ~3,095 | ___ | ☐ |
| geolocation | ~1,000,163 | ___ | ☐ |
| category_translation | ~71 | ___ | ☐ |
 - all matches
---

## 1. Orders

| Metric | Value |
|---|---|
| Row count | 99441 |
| Distinct order_id | 99441 |
| Key uniqueness OK? (row count == distinct) | ☐ Yes ☐ No | Yes
| % null order_approved_at | 0.16% | 160
| % null order_delivered_carrier_date | 1.79% | 1783
| % null order_delivered_customer_date | 2.98% | 2965
| Date range (purchase_timestamp) | 2016-09-04 21:15:19 UTC to 2018-10-17 17:30:18 UTC |
| Unparseable timestamps | 0 |
| approved_before_purchase (consistency flag) | 0 |
| delivered_before_purchase (consistency flag) | 0 |

**order_status distribution:**
| Status |      Count | % |
1   delivered	96478	97.02
2	shipped	    1107	1.11
3	canceled	625	    0.63
4	unavailable	609	    0.61
5	invoiced	314	    0.32
6	processing	301	    0.3
7	created	    5	    0.01
8	approved	2	    0.0

**Null delivered_customer_date by status (tests MNAR hypothesis — Appendix B.13):**
    | Status|      n | null_delivered | pct_null |
1   delivered	96478	    8	        0.01
2	shipped	    1107	    1107	    100.0
3	canceled	625	        619	        99.04
4	unavailable	609	        609	        100.0
5	invoiced	314	        314	        100.0
6	processing	301	        301	        100.0
7	created	    5	        5	        100.0
8	approved	2	        2	        100.0

> **Finding:** ___ (confirm/deny: nulls are concentrated in non-delivered statuses → structural/MNAR) - 8 of them are in non-delivered status for completed delivery and 6 are not null for canceled orders

**Monthly volume — note head/tail completeness:**
First 2 months: ___ / Last 2 months: ___ → **flag for Phase 9/12 trimming:** ☐ Yes ☐ No
first 3 and last 2 months - flag
2016-09	 4
2016-10	 324
2016-12	 1

last 2 months
2018-09	 16
2018-10	 4
---

1. Sep 2016: 4 orders. Oct 2016: 324. Dec 2016: 1. Last months — Sep 2018: 16, Oct 2018: 4. These are clearly partial months at the boundary of the dataset, not business dips. Including them in trend or monthly-growth analysis will manufacture false seasonality and false decline signals.
Trim to Jan 2017 – Aug 2018 for any time-series, trend, or month-on-month analysis. Do NOT trim for aggregate KPIs (count, revenue) — those need the full population.

2. for order_status distribution - shipped (1.11%) are in-flight — their nulls in delivered_customer_date are structural and expected, not data quality problems.

3. ~97% is delivered - Null delivered are 8 out of total delivered - MNAR (structural)

## 2. Customers

| Metric | Value |
|---|---|
| Row count | 99441 |
| Distinct customer_id | 99441 |
| Distinct customer_unique_id | 96096 |
| Orders-per-person ratio | 1.035 |
| % null customer_state | 0% |

> **Critical finding:** customer_id is essentially 1:1 with rows (one per order); customer_unique_id is lower, confirming most customers are one-time buyers. **Decision carried forward: use `customer_unique_id` for every customer/retention/RFM analysis (Phase 7+).**

**Repeat-purchase distribution:**
orders_per_person	num_people	%
1	                93099		96.88
2	                2745		2.86
3	                203			0.21
4	                30			0.03
5	                8			0.01
6	                6			0.01
7	                3			0
9	                1			0
17	                1			0
1 customer placed 9 and 17 times order

**Top states by customer count:**
| State |    n |      % |
SP	       41746	41.98
RJ	       12852	12.92
MG	       11635	11.7

1. customer_id: 99,441 unique (one per order). customer_unique_id: 96,096 unique (one per person). Ratio = 1.035 — most customers bought once. The two IDs differ by 3,345 rows — those are repeat buyers. 
 use customer_unique_id for ALL customer-level analysis, retention, RFM, cohort, and LTV from this point forward. Non-negotiable.

2. 93,099 customers bought once (96.88%). 2,745 bought twice. 203 three times. 1 customer bought 17 times. One-time buyer dominance is the central customer insight of this dataset — not a data problem.
---

## 3. Order Items

| Metric | Value |
|---|---|
| Row count | 112650 |
| Distinct orders | 98666 |
| Avg items per order | 1.14 |
| % null product_id / seller_id / price / freight_value | 0 |

**Price & freight_value range:**
| Column | Min | Max | Avg | Q1 | Median | Q3 |
|---|---|---|---|---|---|---|
column_name	    min_val	max_val	avg_val	quartiles
price	        0.85	6735.0	120.65	0.85
					                    39.9
					                    75.0
					                    135.0
					                    6735.0
freight_value	0.0	    409.68	19.99	0.0
					                    13.08
					                    16.25
					                    21.15
					                    409.68
> **Flag for Phase 5:** mean vs median gap on price/freight → ___ (note skew direction; full skew/kurtosis computed in Phase 5)

**Items-per-order distribution:** ___ (e.g. % single-item orders vs multi-item)
1. Price and freight right-skew confirmed — mean far above median
Price: min R$0.85, max R$6,735, avg R$120.65 but Q1=R$39.90, median=R$75.00, Q3=R$135.00. The mean (120.65) sits well above the median (75.00) — a classic right-skew signature. A few extremely high-value products are pulling the mean up. Freight: min R$0.00, max R$409.68, avg R$19.99, median=R$16.25 — similar pattern, less severe.
 - Treatment implications — 
 (1) use median not mean for imputation of any missing values, 
 (2) apply 	log-transform before using these as ML features, 
 (3) report median AOV to stakeholders, not mean, for "typical" order framing. IQR (not z-score) for outlier detection since distribution is not normal.
---

## 4. Order Payments

| Metric | Value |
|---|---|
| Row count | 103886 |
| Distinct orders | 99440 |
| Avg payments per order | 154.1 |

**payment_type distribution:**
| Type |        n |     % |
credit_card	    76795	73.92
boleto	        19784	19.04
voucher	        5775	5.56
debit_card	    1529	1.47
not_defined	    3	    0.0

**payment_installments:** min __0_ / max _24__ / quartiles __0,1,1,4,24_

**payment_value:** min _0__ / max __13664.08_ / avg _154.1__ / quartiles ___ / non-positive count _0__
9 payment values with 0 as value, with payment type as voucher and undefined

investigate these 9 rows. Check whether a corresponding voucher entry covers the full order value. If yes, keep. If not_defined and zero — likely corrupt, flag for exclusion from payment_value analysis (not from order counts), this particular order_id could be present in orders.

Installments: max 24, Q3=4 — many customers use installments, relevant for A/B test on whether installment use predicts higher order values.
---

## 5. Order Reviews

| Metric | Value |
|---|---|
| Row count | 99224 |
| Distinct review_id | 98410 |
| Distinct order_id | 98673 |
| Orders with >1 review | 547 |
| % null review_comment_message | 58.7% |

**review_score distribution:**
| Score | n |   % |
5	    57328	57.78
4	    19142	19.29
1	    11424	11.51
3	    8179	8.24
2	    3151	3.18

## Review score distribution based on review messages null
review_score	n
5				63.13
4				22.6
3				7.94
1				4.6
2				1.73

1. Most customers leave a score but no comment. This is NOT a data quality issue — it's behavioral. Customers who do leave comments are a self-selected group (likely more extreme, positive or negative).
Mostly 5* leave comments section as null 
2. Score distribution is bimodal: 57.78% score 5, 11.51% score 1. The middle scores (2-4) are underrepresented — classic satisfied/outraged split.
3. 547 orders have more than 1 review — duplicates. 98,410 distinct review_ids from 98,673 distinct order_ids — slight mismatch. The score distribution (5=57.78%, 1=11.51%) confirms a bimodal/J-shaped distribution, not normal. Mean and std dev are misleading for ordinal 1-5 scores.
Statistical implication: review_score is ordinal (1–5). For group comparisons, use Mann-Whitney U (two groups) or Kruskal-Wallis (3+ groups), NOT t-test or ANOVA — those assume continuous normal distributions.

5 stars = 57.78%, 1 star = 11.51%. Middle scores underrepresented. This is a J-shaped distribution, not even close to normal. Mean and standard deviation are technically calculable but meaningless — the "average rating" of 4.09 hides the polarisation completely.

Critical decisions: (1) NEVER use t-test or ANOVA for review_score comparisons — these assume continuous normal data. (2) Use Mann-Whitney U for two-group comparisons (e.g. late vs on-time) — non-parametric, works on ordinal data. (3) For 3+ groups (e.g. by region): Kruskal-Wallis, then Dunn post-hoc. (4) For reporting: use median score and score distribution (% 5-star, % 1-star) — not mean. (5) For ML target: binarise into positive (4–5) vs negative (1–3) for the Random Forest model.
---

## 6. Products

| Metric | Value |
|---|---|
| Row count | 32951 |
| Distinct product_id | 32951 |
| % null product_category_name | 1.85% | 610
| % null weight/length/height/width | ___% | 2 products with 0 values - needs to be handled for filling missing values
| Distinct categories | 73 |
| Zero-weight products | 4 | all 4 products are from 'cama_mesa_banho' - needs to be handled

**Top 10 categories by product count:** ___

Decisions: 
(1) Null category_name → check if these products appear in order_items. If yes, impute with mode (most common category — B.3) or create an "Unknown" category — do NOT drop these rows since the order/revenue data is still valid. 
(2) Zero-weight/dimension: physical products cannot have zero weight — these are measurement errors. Impute with category median weight (B.2) — median because weight is likely right-skewed. 
(3) Missing translations: manually add "portateis_cozinha_e_preparadores_de_alimentos" → "portable kitchen appliances" and "pc_gamer" → "PC gaming".

---

## 7. Sellers

| Metric | Value |
|---|---|
| Row count | 3095 |
| Distinct seller_id | 3095 |
| % null zip/city/state | 0% |

**Top states by seller count:** ___
SP	1849
PR	349
MG	244
---

## 8. Geolocation

| Metric | Value |
|---|---|
| Row count | 1000163 |
| Distinct zip prefixes | 19015 |
| Avg rows per zip | 52.6 |
| Out-of-Brazil-bbox coordinates | 42 |
(Brazil bounding box ~ lat -34 to 5, lng -74 to -34)
min_lat				max_lat				min_lng				max_lng				out_of_brazil_bbox
-36.6053744107061	45.065933182696973	-101.46676644931476	121.10539381057764	42

> **Structural note confirmed:** geolocation has many rows per zip prefix → **must aggregate (AVG lat/lng) before joining**, never join raw (carried into Phase 6/7).


Decisions: 
(1) Remove 42 out-of-Brazil rows before aggregation. 
(2) Aggregate geolocation by zip prefix using AVG(lat), AVG(lng) → one row per zip. Then join this aggregated table.

---

## 9. Category Translation

| Metric | Value |
|---|---|
| Row count | 71 |
| Distinct PT category names | 71 |
| Product categories missing a translation | __2_ (list: ___) |
- portateis_cozinha_e_preparadores_de_alimentos
- pc_gamer

---

## Summary of flagged issues → carried into Phase 4 issue register

| # | Table.Column | Issue | Evidence | Proposed mechanism |
|---|---|---|---|---|
| 1 | orders.order_delivered_customer_date | Missing | 0.01% null, concentrated in non-delivered statuses | MNAR/structural | (8 values)
| 2 | products.product_category_name | Missing | ___% null | MAR | 
| 3 | order_items.price / freight_value | Right skew (mean > median) | ___ | n/a — quantify in Phase 5 |
| 4 | products.* | Some categories missing translation | ___ categories | Coverage gap | 2 values
| 5 | geolocation | Many rows per zip | avg ___ rows/zip | Structural — aggregate before join |
| 6 | customers.customer_id vs customer_unique_id | Grain trap | ratio ___ | Use unique_id downstream |

---

## Success criteria check
- [ ] Every column of every table has a documented row count, null rate, and range/top-values entry.
- [ ] Every anomaly above is flagged (not yet fixed) and ready to feed Phase 4's issue register.
- [ ] Customer key cardinality confirmed and decision documented.
- [ ] Geolocation fan-out risk confirmed and documented.

**Next phase:** [Phase 4 — Data Quality Assessment](../guide/phase-04-data-quality-assessment.md)
