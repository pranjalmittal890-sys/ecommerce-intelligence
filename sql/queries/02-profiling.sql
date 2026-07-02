-- ============================================================================
-- DATA PROFILING — EXECUTION SQL
-- Project: Olist Brazilian E-Commerce Analytics
-- Engine:  BigQuery (GoogleSQL)
-- Prereq:  complete — olist_raw.* tables loaded
-- Usage:   Replace `olist-analytics-500708` with your actual GCP project id everywhere.
-- ============================================================================

-- What to profile (checklist per table)
-- Row count + distinct key count (uniqueness of PK).
-- Null rate of every column.
-- For dates: min/max range, count of out-of-range/future dates.
-- For categoricals: distinct count + top values + frequency.
-- For numerics: min/max/avg + quartiles (`APPROX_QUANTILES`).

-- ============================================================================
-- 0. WAREHOUSE SANITY CHECK — confirm all 9 tables exist with sensible row counts
-- ============================================================================
SELECT table_name, row_count, size_bytes
FROM `olist-analytics-500708.olist_raw.__TABLES__`
ORDER BY table_name;
-- Expected ballpark: orders ~99k, order_items ~112k, order_payments ~104k,
-- order_reviews ~99k, customers ~99k, products ~32k, sellers ~3k,
-- geolocation ~1M, category_translation ~71


-- ============================================================================
-- 1. ORDERS  (olist_raw.orders)
-- Grain: one row = one order
-- ============================================================================

-- 1.1 Row count, key uniqueness, null profile
SELECT
  COUNT(*)                                                  AS row_count,
  COUNT(DISTINCT order_id)                                  AS distinct_order_id,
  COUNTIF(order_id IS NULL)                                 AS null_order_id,
  COUNTIF(customer_id IS NULL)                              AS null_customer_id,
  COUNTIF(order_status IS NULL)                             AS null_status,
  COUNTIF(order_purchase_timestamp IS NULL)                 AS null_purchase_ts,
  COUNTIF(order_approved_at IS NULL)                        AS null_approved_at,
  COUNTIF(order_delivered_carrier_date IS NULL)             AS null_delivered_carrier,
  COUNTIF(order_delivered_customer_date IS NULL)            AS null_delivered_customer,
  COUNTIF(order_estimated_delivery_date IS NULL)             AS null_estimated_delivery
FROM `olist-analytics-500708.olist_raw.orders`;

-- 1.2 Null rate as % (easier to compare across columns)
SELECT
  ROUND(COUNTIF(order_approved_at IS NULL) / COUNT(*) * 100, 2)            AS pct_null_approved,
  ROUND(COUNTIF(order_delivered_carrier_date IS NULL) / COUNT(*) * 100, 2) AS pct_null_carrier,
  ROUND(COUNTIF(order_delivered_customer_date IS NULL) / COUNT(*) * 100, 2) AS pct_null_delivered
FROM `olist-analytics-500708.olist_raw.orders`;

-- 1.3 order_status frequency distribution
SELECT
  order_status,
  COUNT(*) AS n,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM `olist-analytics-500708.olist_raw.orders`
GROUP BY order_status
ORDER BY n DESC;

-- 1.4 Cross-check: is null delivered_customer_date concentrated in non-'delivered' status?
-- (tests the MNAR/structural-missing hypothesis from Appendix B.13)
SELECT
  order_status,
  COUNT(*) AS n,
  COUNTIF(order_delivered_customer_date IS NULL) AS null_delivered,
  ROUND(COUNTIF(order_delivered_customer_date IS NULL) / COUNT(*) * 100, 2) AS pct_null
FROM `olist-analytics-500708.olist_raw.orders`
GROUP BY order_status
ORDER BY n DESC;

-- 1.5 Date range sanity (raw timestamps are STRING pre-Phase-6 — cast for profiling only)
SELECT
  MIN(SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)) AS min_purchase_ts,
  MAX(SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)) AS max_purchase_ts,
  COUNTIF(SAFE_CAST(order_purchase_timestamp AS TIMESTAMP) IS NULL
          AND order_purchase_timestamp IS NOT NULL)     AS unparseable_purchase_ts
FROM `olist-analytics-500708.olist_raw.orders`;

-- 1.6 Logical consistency: any timestamps out of order? (full check belongs to Phase 4,
-- but worth a first look here as a profiling red flag)
SELECT
  COUNTIF(SAFE_CAST(order_approved_at AS TIMESTAMP) < SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)) AS approved_before_purchase,
  COUNTIF(SAFE_CAST(order_delivered_customer_date AS TIMESTAMP) < SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)) AS delivered_before_purchase
FROM `olist-analytics-500708.olist_raw.orders`;

-- 1.7 Monthly volume — eyeball the head/tail completeness issue mentioned in the guide
SELECT
  FORMAT_TIMESTAMP('%Y-%m', SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)) AS year_month,
  COUNT(*) AS orders
FROM `olist-analytics-500708.olist_raw.orders`
GROUP BY year_month
ORDER BY year_month;


-- ============================================================================
-- 2. CUSTOMERS  (olist_raw.customers)
-- Grain: one row = one order's customer record (NOT one row per person)
-- ============================================================================

-- 2.1 Row count + the critical cardinality check: customer_id vs customer_unique_id
SELECT
  COUNT(*)                              AS rows,
  COUNT(DISTINCT customer_id)           AS uniq_customer_id,
  COUNT(DISTINCT customer_unique_id)    AS uniq_person,
  ROUND(COUNT(DISTINCT customer_id) / COUNT(DISTINCT customer_unique_id), 3) AS orders_per_person_ratio
FROM `olist-analytics-500708.olist_raw.customers`;
-- Expect uniq_customer_id ~= rows (near 1:1), uniq_person somewhat lower
-- → confirms most customers are one-time buyers; use customer_unique_id everywhere downstream

-- 2.2 Null profile
SELECT
  COUNTIF(customer_id IS NULL)                AS null_customer_id,
  COUNTIF(customer_unique_id IS NULL)         AS null_unique_id,
  COUNTIF(customer_zip_code_prefix IS NULL)   AS null_zip,
  COUNTIF(customer_city IS NULL)              AS null_city,
  COUNTIF(customer_state IS NULL)              AS null_state
FROM `olist-analytics-500708.olist_raw.customers`;

-- 2.3 State distribution (low-cardinality dimension check)
SELECT customer_state, COUNT(*) AS n,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM `olist-analytics-500708.olist_raw.customers`
GROUP BY customer_state
ORDER BY n DESC;

-- 2.4 Repeat-purchase distribution (how many orders per unique person)
SELECT orders_per_person, COUNT(*) AS num_people
FROM (
  SELECT customer_unique_id, COUNT(*) AS orders_per_person
  FROM `olist-analytics-500708.olist_raw.customers`
  GROUP BY customer_unique_id
)
GROUP BY orders_per_person
ORDER BY orders_per_person;


-- ============================================================================
-- 3. ORDER_ITEMS  (olist_raw.order_items)
-- Grain: one row = one item line within an order (multiple rows per order_id expected)
-- ============================================================================

-- 3.1 Row count + grain check (rows per order should be > order count)
SELECT
  COUNT(*)                       AS rows,
  COUNT(DISTINCT order_id)       AS distinct_orders,
  ROUND(COUNT(*) / COUNT(DISTINCT order_id), 2) AS avg_items_per_order
FROM `olist-analytics-500708.olist_raw.order_items`;

-- 3.2 Null profile
SELECT
  COUNTIF(product_id IS NULL) AS null_product,
  COUNTIF(seller_id IS NULL)  AS null_seller,
  COUNTIF(price IS NULL)      AS null_price,
  COUNTIF(freight_value IS NULL) AS null_freight
FROM `olist-analytics-500708.olist_raw.order_items`;

-- 3.3 Numeric range + quartiles for price and freight_value (drives Phase 5 evidence)
SELECT
  'price' AS column_name,
  MIN(price) AS min_val, MAX(price) AS max_val,
  ROUND(AVG(price), 2) AS avg_val,
  APPROX_QUANTILES(price, 4) AS quartiles
FROM `olist-analytics-500708.olist_raw.order_items`
UNION ALL
SELECT
  'freight_value',
  MIN(freight_value), MAX(freight_value),
  ROUND(AVG(freight_value), 2),
  APPROX_QUANTILES(freight_value, 4)
FROM `olist-analytics-500708.olist_raw.order_items`;

-- 3.4 Items-per-order distribution (informs the order-grain aggregation in Phase 7)
SELECT items_per_order, COUNT(*) AS num_orders
FROM (
  SELECT order_id, COUNT(*) AS items_per_order
  FROM `olist-analytics-500708.olist_raw.order_items`
  GROUP BY order_id
)
GROUP BY items_per_order
ORDER BY items_per_order;


-- ============================================================================
-- 4. ORDER_PAYMENTS  (olist_raw.order_payments)
-- Grain: one row = one payment installment (multiple rows per order_id expected)
-- ============================================================================

-- 4.1 Row count + grain check
SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT order_id) AS distinct_orders,
  ROUND(COUNT(*) / COUNT(DISTINCT order_id), 2) AS avg_payments_per_order
FROM `olist-analytics-500708.olist_raw.order_payments`;

-- 4.2 payment_type frequency (watch for 'not_defined')
SELECT payment_type, COUNT(*) AS n,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM `olist-analytics-500708.olist_raw.order_payments`
GROUP BY payment_type
ORDER BY n DESC;

-- 4.3 payment_installments range + distribution
SELECT
  MIN(payment_installments) AS min_installments,
  MAX(payment_installments) AS max_installments,
  APPROX_QUANTILES(payment_installments, 4) AS quartiles
FROM `olist-analytics-500708.olist_raw.order_payments`;

-- 4.4 payment_value range + quartiles
SELECT
  MIN(payment_value) AS min_val, MAX(payment_value) AS max_val,
  ROUND(AVG(payment_value), 2) AS avg_val,
  APPROX_QUANTILES(payment_value, 4) AS quartiles,
  COUNTIF(payment_value <= 0) AS non_positive_count
FROM `olist-analytics-500708.olist_raw.order_payments`;


-- ============================================================================
-- 5. ORDER_REVIEWS  (olist_raw.order_reviews)
-- Grain: one row = one review (occasionally multiple per order_id)
-- ============================================================================

-- 5.1 Row count + grain check
SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT review_id) AS distinct_reviews,
  COUNT(DISTINCT order_id) AS distinct_orders
FROM `olist-analytics-500708.olist_raw.order_reviews`;

-- 5.2 review_score distribution
SELECT review_score, COUNT(*) AS n,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM `olist-analytics-500708.olist_raw.order_reviews`
GROUP BY review_score
ORDER BY review_score;

-- 5.3 Null profile (comment text fields are often sparsely filled — expected)
SELECT
  COUNTIF(review_score IS NULL) AS null_score,
  COUNTIF(review_comment_title IS NULL) AS null_title,
  COUNTIF(review_comment_message IS NULL) AS null_message,
  ROUND(COUNTIF(review_comment_message IS NULL) / COUNT(*) * 100, 2) AS pct_null_message
FROM `olist-analytics-500708.olist_raw.order_reviews`;

-- 5.4 Orders with more than one review (grain anomaly check)
SELECT reviews_per_order, COUNT(*) AS num_orders
FROM (
  SELECT order_id, COUNT(*) AS reviews_per_order
  FROM `olist-analytics-500708.olist_raw.order_reviews`
  GROUP BY order_id
)
GROUP BY reviews_per_order
ORDER BY reviews_per_order;


-- ============================================================================
-- 6. PRODUCTS  (olist_raw.products)
-- Grain: one row = one product
-- ============================================================================

-- 6.1 Row count + key uniqueness
SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT product_id) AS distinct_products
FROM `olist-analytics-500708.olist_raw.products`;

-- 6.2 Null profile (category and dimension fields)
SELECT
  COUNTIF(product_category_name IS NULL)   AS null_category,
  COUNTIF(product_weight_g IS NULL)        AS null_weight,
  COUNTIF(product_length_cm IS NULL)       AS null_length,
  COUNTIF(product_height_cm IS NULL)       AS null_height,
  COUNTIF(product_width_cm IS NULL)        AS null_width,
  COUNTIF(product_photos_qty IS NULL)      AS null_photos_qty
FROM `olist-analytics-500708.olist_raw.products`;

-- 6.3 Category cardinality + top categories
SELECT
  COUNT(DISTINCT product_category_name) AS distinct_categories
FROM `olist-analytics-500708.olist_raw.products`;

SELECT product_category_name, COUNT(*) AS n
FROM `olist-analytics-500708.olist_raw.products`
GROUP BY product_category_name
ORDER BY n DESC
LIMIT 20;

-- 6.4 Weight/dimension range (sanity check for zero/negative/absurd values)
SELECT
  MIN(product_weight_g) AS min_weight, MAX(product_weight_g) AS max_weight,
  COUNTIF(product_weight_g = 0) AS zero_weight_count
FROM `olist-analytics-500708.olist_raw.products`;


-- ============================================================================
-- 7. SELLERS  (olist_raw.sellers)
-- Grain: one row = one seller
-- ============================================================================

SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT seller_id) AS distinct_sellers,
  COUNTIF(seller_zip_code_prefix IS NULL) AS null_zip,
  COUNTIF(seller_city IS NULL) AS null_city,
  COUNTIF(seller_state IS NULL) AS null_state
FROM `olist-analytics-500708.olist_raw.sellers`;

SELECT seller_state, COUNT(*) AS n
FROM `olist-analytics-500708.olist_raw.sellers`
GROUP BY seller_state
ORDER BY n DESC;


-- ============================================================================
-- 8. GEOLOCATION  (olist_raw.geolocation)
-- Grain: one row = one lat/lng point per zip prefix (MANY rows per zip — do not join raw)
-- ============================================================================

SELECT
  COUNT(*) AS rows,
  COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip_prefixes,
  ROUND(COUNT(*) / COUNT(DISTINCT geolocation_zip_code_prefix), 2) AS avg_rows_per_zip
FROM `olist-analytics-500708.olist_raw.geolocation`;
-- High avg_rows_per_zip confirms: this table MUST be aggregated (AVG lat/lng) before
-- joining to customers/sellers — never join raw (Phase 2 + Phase 6 reminder)

-- Lat/lng range sanity (Brazil bounding box ~ lat -34 to 5, lng -74 to -34)
SELECT
  MIN(geolocation_lat) AS min_lat, MAX(geolocation_lat) AS max_lat,
  MIN(geolocation_lng) AS min_lng, MAX(geolocation_lng) AS max_lng,
  COUNTIF(geolocation_lat NOT BETWEEN -34 AND 6
       OR geolocation_lng NOT BETWEEN -75 AND -33) AS out_of_brazil_bbox
FROM `olist-analytics-500708.olist_raw.geolocation`;


-- ============================================================================
-- 9. CATEGORY_TRANSLATION  (olist_raw.category_translation)
-- Grain: one row = one PT→EN category mapping
-- ============================================================================

SELECT COUNT(*) AS rows,
       COUNT(DISTINCT product_category_name) AS distinct_pt_names
FROM `olist-analytics-500708.olist_raw.category_translation`;

-- Coverage check: which product categories have NO English translation?
-- (anticipates a Phase 4 referential-integrity issue)
SELECT DISTINCT p.product_category_name
FROM `olist-analytics-500708.olist_raw.products` p
LEFT JOIN `olist-analytics-500708.olist_raw.category_translation` t
  ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;


-- ============================================================================
-- END OF PHASE EXECUTION SQL
-- ============================================================================
