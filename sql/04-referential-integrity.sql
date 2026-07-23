-- ============================================================================
-- PHASE 4 — DATA QUALITY ASSESSMENT — EXECUTION SQL
-- Prereq: Phase 3 profiling complete.
-- ============================================================================

-- ============================================================================
-- A. REFERENTIAL INTEGRITY (anti-join pattern — every result below should be 0;
--    any non-zero count is a logged defect)
-- ============================================================================


-- RI-7 (reverse direction): Every order should have at least one order_item
-- (an order with zero items would be a business-logic anomaly, not just
-- a strict FK violation — orders shouldn't exist without line items)
SELECT COUNT(*) AS orders_with_no_items
FROM `olist-analytics-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708.olist_raw.order_items` oi
  ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;
-- 775 records - Non-zero counts here don't necessarily mean "bad data" — 
-- an order with no items could be a cancelled-before-fulfillment edge case.

-- Pull the 8 non-conforming rows for manual inspection
SELECT o.order_id, o.order_status, o.order_purchase_timestamp,
       o.order_approved_at, o.order_delivered_carrier_date, o.order_delivered_customer_date
FROM `olist-analytics-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708.olist_raw.order_items` oi
  ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
  AND o.order_status IN ('created', 'invoiced', 'shipped')
ORDER BY o.order_status;

-- RI-5: Every payment must belong to a valid order
-- A.2 order_payments -> orders
SELECT COUNT(*) AS orphan_payments_no_order
FROM `olist-analytics-500708-500708.olist_raw.order_payments` p
LEFT JOIN `olist-analytics-500708-500708.olist_raw.orders` o USING (order_id)
WHERE o.order_id IS NULL;

-- RI-8: Every order should have at least one payment record
-- (profiling already found 1 exception anecdotally — this confirms the
-- true baseline count)
SELECT COUNT(*) AS orders_with_no_payment
FROM `olist-analytics-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708.olist_raw.order_payments` op
  ON o.order_id = op.order_id
WHERE op.order_id IS NULL;
-- there is 1 record in payment table that does not have an entry in payments table but 
--in orders table, because of which 1 record is present in payment and not in orders.
--  Documented, no cleaning action.

-- RI-6: Every review must belong to a valid order
-- A.3 order_reviews -> orders
SELECT COUNT(*) AS orphan_reviews_no_order
FROM `olist-analytics-500708-500708.olist_raw.order_reviews` r
LEFT JOIN `olist-analytics-500708-500708.olist_raw.orders` o USING (order_id)
WHERE o.order_id IS NULL;
-- 0

-- RI-9: Orders with no review
SELECT
  COUNT(*) AS orders_with_no_review,
  ROUND(COUNT(*) / (SELECT COUNT(*) FROM `olist-analytics-500708.olist_raw.orders`) * 100, 2) AS pct_of_orders
FROM `olist-analytics-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708.olist_raw.order_reviews` r
  ON o.order_id = r.order_id
WHERE r.order_id IS NULL;
-- Reviews are optional. No action, not even documentation as an "issue" — 
--this is just a coverage fact.


-- RI-1: Every order must have a valid customer
-- A.6 orders -> customers
SELECT COUNT(*) AS orphan_orders_no_customer
FROM `olist-analytics-500708-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708-500708.olist_raw.customers` c USING (customer_id)
WHERE c.customer_id IS NULL;

-- 0 values for join for customers, so no orphan orders exist in the dataset.

-- RI-3: Every order_item must reference a valid product
-- A.4 order_items -> products
SELECT COUNT(*) AS orphan_items_no_product
FROM `olist-analytics-500708-500708.olist_raw.order_items` oi
LEFT JOIN `olist-analytics-500708-500708.olist_raw.products` p USING (product_id)
WHERE p.product_id IS NULL;

-- 0

-- RI-4: Every order_item must reference a valid seller
-- A.5 order_items -> sellers
SELECT COUNT(*) AS orphan_items_no_seller
FROM `olist-analytics-500708-500708.olist_raw.order_items` oi
LEFT JOIN `olist-analytics-500708-500708.olist_raw.sellers` s USING (seller_id)
WHERE s.seller_id IS NULL;

-- 0

-- RI-2: Every order_item must belong to a valid order
-- A.1 order_items -> orders
SELECT COUNT(*) AS orphan_items_no_order
FROM `olist-analytics-500708-500708.olist_raw.order_items` oi
LEFT JOIN `olist-analytics-500708-500708.olist_raw.orders` o USING (order_id)
WHERE o.order_id IS NULL;

-- 0 values for cross join for both orders and order_items, so no orphan items exist in the dataset.


-- A.7 products -> category_translation (coverage gap, not strictly orphan)
SELECT COUNT(DISTINCT p.product_category_name) AS categories_missing_translation
FROM `olist-analytics-500708-500708.olist_raw.products` p
LEFT JOIN `olist-analytics-500708-500708.olist_raw.category_translation` t
  ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL;
 --answer = 2
 --Documented, no cleaning action

-- A.8 orders -> order_items (orders with zero items — should be near 0 for delivered orders)
SELECT o.order_status, COUNT(*) AS orders_with_no_items
FROM `olist-analytics-500708-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708-500708.olist_raw.order_items` oi USING (order_id)
WHERE oi.order_id IS NULL
GROUP BY o.order_status;

--order_status	orders_with_no_items
/*canceled	164
created	    5
invoiced	2
shipped	    1
unavailable	603
*/

-- A.9 orders -> order_payments (orders with zero payments — should be near 0)
SELECT o.order_status, COUNT(*) AS orders_with_no_payment
FROM `olist-analytics-500708-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708-500708.olist_raw.order_payments` p USING (order_id)
WHERE p.order_id IS NULL
GROUP BY o.order_status;

-- delivered	1

-- RI-11: customers.customer_zip_code_prefix -> geolocation.geolocation_zip_code_prefix
-- Coverage check, not a strict FK (Olist doesn't declare this relationship
-- formally — geolocation is a separately-sourced reference table).
-- Non-zero here means some customer zips have no coordinate data at all.
SELECT
  COUNT(DISTINCT c.customer_zip_code_prefix) AS customer_zips_missing_geo
FROM `olist-analytics-500708.olist_raw.customers` c
LEFT JOIN `olist-analytics-500708.olist_raw.geolocation` g
  ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;
--157

-- RI-12: sellers.seller_zip_code_prefix -> geolocation.geolocation_zip_code_prefix
SELECT
  COUNT(DISTINCT s.seller_zip_code_prefix) AS seller_zips_missing_geo
FROM `olist-analytics-500708.olist_raw.sellers` s
LEFT JOIN `olist-analytics-500708.olist_raw.geolocation` g
  ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL;
--7

-- Investigate RI-7: what status do orders-with-no-items have?
SELECT
  o.order_status,
  COUNT(*) AS n,
  ROUND(COUNT(*) / 775 * 100, 2) AS pct_of_orphan_orders
FROM `olist-analytics-500708.olist_raw.orders` o
LEFT JOIN `olist-analytics-500708.olist_raw.order_items` oi
  ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY n DESC;
-- Row	order_status	n	pct_of_orphan_orders
-- 1	unavailable	603	77.81
-- 2	canceled	164	21.16
-- 3	created	5	0.65
-- 4	invoiced	2	0.26
-- 5	shipped	1	0.13

-- Investigate RI-11: which states are affected by missing customer zip coverage?
SELECT
  c.customer_state,
  COUNT(DISTINCT c.customer_zip_code_prefix) AS missing_zips,
  COUNT(*) AS affected_customer_rows
FROM `olist-analytics-500708.olist_raw.customers` c
LEFT JOIN `olist-analytics-500708.olist_raw.geolocation` g
  ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL
GROUP BY c.customer_state
ORDER BY missing_zips DESC;
--total 21 rows, first 10 as below -
-- Row	customer_state	missing_zips	affected_customer_rows
-- 1	DF	67	171
-- 2	SP	14	15
-- 3	MG	11	11
-- 4	PR	10	11
-- 5	RJ	10	13
-- 6	BA	7	9
-- 7	GO	6	9
-- 8	PE	4	4
-- 9	RS	4	4
-- 10	CE	3	4

-- Investigate RI-12: same for sellers
SELECT
  s.seller_state,
  COUNT(DISTINCT s.seller_zip_code_prefix) AS missing_zips,
  COUNT(*) AS affected_seller_rows
FROM `olist-analytics-500708.olist_raw.sellers` s
LEFT JOIN `olist-analytics-500708.olist_raw.geolocation` g
  ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE g.geolocation_zip_code_prefix IS NULL
GROUP BY s.seller_state
ORDER BY missing_zips DESC;
--total 5
-- Row	seller_state	missing_zips	affected_seller_rows
-- 1	SP	2	2
-- 2	DF	2	2
-- 3	MG	1	1
-- 4	PR	1	1
-- 5	RS	1	1

--"Referential integrity was validated across all 6 foreign-key relationships in the 
--schema with zero orphaned records found."

-- ============================================================================
-- B. CONSISTENCY CHECKS (logical timestamp / value ordering)
-- ============================================================================

-- B.1 Timestamp ordering violations in orders
SELECT
  COUNTIF(SAFE_CAST(order_approved_at AS TIMESTAMP) < SAFE_CAST(order_purchase_timestamp AS TIMESTAMP))            AS approved_before_purchase,
  COUNTIF(SAFE_CAST(order_delivered_carrier_date AS TIMESTAMP) < SAFE_CAST(order_approved_at AS TIMESTAMP))        AS carrier_before_approved,
  COUNTIF(SAFE_CAST(order_delivered_customer_date AS TIMESTAMP) < SAFE_CAST(order_delivered_carrier_date AS TIMESTAMP)) AS customer_before_carrier,
  COUNTIF(SAFE_CAST(order_delivered_customer_date AS TIMESTAMP) < SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)) AS delivered_before_purchase
FROM `olist-analytics-500708-500708.olist_raw.orders`;

--approved_before_purchase    carrier_before_approved	    customer_before_carrier	    delivered_before_purchase
--    0	                        1359	                    23	                        0

-- B.2 Negative or zero monetary values (should be investigated, not assumed errors)
SELECT
  COUNTIF(price <= 0) AS non_positive_price,
  COUNTIF(freight_value < 0) AS negative_freight
FROM `olist-analytics-500708-500708.olist_raw.order_items`;

SELECT COUNTIF(payment_value <= 0) AS non_positive_payment_value
FROM `olist-analytics-500708-500708.olist_raw.order_payments`;

-- non_positive_payment_value = 9
/*
SELECT
  order_id, payment_sequential, payment_type, payment_installments, payment_value
FROM `olist-analytics-500708.olist_raw.order_payments`
WHERE payment_value = 0
ORDER BY order_id, payment_sequential;

SELECT
  p.order_id,
  COUNT(*) AS payment_rows_for_order,
  SUM(p.payment_value) AS total_paid,
  STRING_AGG(p.payment_type, ', ') AS payment_types_used
FROM `olist-analytics-500708.olist_raw.order_payments` p
WHERE p.order_id IN (
  SELECT order_id FROM `olist-analytics-500708.olist_raw.order_payments` WHERE payment_value = 0
)
GROUP BY p.order_id;

select o.order_id, o.order_status, p.payment_type
from `olist-analytics-500708.olist_raw.orders` o
left join `olist-analytics-500708.olist_raw.order_payments` p
using(order_id)
where p.payment_value=0
*/
-- the above queries prove that the 3 not_defined payment_type rows are all for canceled orders, 
-- so they can be treated as unknown and retained in the cleaned dataset.
-- rest 6 entries are valid

-- B.3 review_score out of expected 1-5 range
SELECT COUNTIF(review_score NOT BETWEEN 1 AND 5) AS invalid_review_score
FROM `olist-analytics-500708-500708.olist_raw.order_reviews`;

-- B.4 Future-dated orders (data-entry errors relative to dataset's known max date)
SELECT COUNT(*) AS future_dated_orders
FROM `olist-analytics-500708-500708.olist_raw.orders`
WHERE SAFE_CAST(order_purchase_timestamp AS TIMESTAMP) > CURRENT_TIMESTAMP();


-- ============================================================================
-- C. UNIQUENESS / KEY VALIDATION (at correct grain — see Phase 2 grain notes)
-- ============================================================================

-- C.1 orders.order_id should be unique
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids
FROM `olist-analytics-500708-500708.olist_raw.orders`;

-- C.2 order_items composite key (order_id, order_item_id) should be unique
SELECT COUNT(*) - COUNT(DISTINCT CONCAT(order_id, '-', CAST(order_item_id AS STRING))) AS duplicate_item_keys
FROM `olist-analytics-500708-500708.olist_raw.order_items`;

-- C.3 products.product_id should be unique
SELECT COUNT(*) - COUNT(DISTINCT product_id) AS duplicate_product_ids
FROM `olist-analytics-500708-500708.olist_raw.products`;

-- C.4 sellers.seller_id should be unique
SELECT COUNT(*) - COUNT(DISTINCT seller_id) AS duplicate_seller_ids
FROM `olist-analytics-500708-500708.olist_raw.sellers`;

-- C.5 Exact full-row duplicates anywhere in orders (defensive check)
SELECT COUNT(*) AS exact_duplicate_order_rows
FROM (
  SELECT order_id, customer_id, order_status, order_purchase_timestamp,
         COUNT(*) AS n
  FROM `olist-analytics-500708-500708.olist_raw.orders`
  GROUP BY 1,2,3,4
  HAVING n > 1
);

-- ============================================================================
-- D. ISSUE REGISTER ROW GENERATOR 
-- ============================================================================
SELECT 'orphan_items_no_order' AS issue, (SELECT COUNT(*) FROM `olist-analytics-500708.olist_raw.order_items` oi LEFT JOIN `olist-analytics-500708.olist_raw.orders` o USING(order_id) WHERE o.order_id IS NULL) AS evidence_count
UNION ALL
SELECT 'orphan_payments_no_order', (SELECT COUNT(*) FROM `olist-analytics-500708.olist_raw.order_payments` p LEFT JOIN `olist-analytics-500708.olist_raw.orders` o USING(order_id) WHERE o.order_id IS NULL)
UNION ALL
SELECT 'orphan_reviews_no_order', (SELECT COUNT(*) FROM `olist-analytics-500708.olist_raw.order_reviews` r LEFT JOIN `olist-analytics-500708.olist_raw.orders` o USING(order_id) WHERE o.order_id IS NULL)
UNION ALL
SELECT 'delivered_before_purchase', (SELECT COUNTIF(SAFE_CAST(order_delivered_customer_date AS TIMESTAMP) < SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)) FROM `olist-analytics-500708.olist_raw.orders`)
UNION ALL
SELECT 'non_positive_price', (SELECT COUNTIF(price <= 0) FROM `olist-analytics-500708.olist_raw.order_items`)
UNION ALL
SELECT 'invalid_review_score', (SELECT COUNTIF(review_score NOT BETWEEN 1 AND 5) FROM `olist-analytics-500708.olist_raw.order_reviews`)
UNION ALL
SELECT 'duplicate_order_ids', (SELECT COUNT(*) - COUNT(DISTINCT order_id) FROM `olist-analytics-500708.olist_raw.orders`)
UNION ALL
SELECT 'categories_missing_translation', (SELECT COUNT(DISTINCT p.product_category_name) FROM `olist-analytics-500708.olist_raw.products` p LEFT JOIN `olist-analytics-500708.olist_raw.category_translation` t ON p.product_category_name = t.string_field_0 WHERE p.product_category_name IS NOT NULL AND t.string_field_0 IS NULL);
