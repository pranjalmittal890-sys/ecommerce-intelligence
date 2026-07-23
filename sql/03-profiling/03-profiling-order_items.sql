SELECT count(*) as row_cnt,
count(distinct order_id) as order_count,
count(distinct order_item_id) as order_items,
count(distinct product_id) as product_cnt,
count(distinct seller_id) as seller_cnt
FROM `olist-analytics-500708.olist_raw.order_items` 

-- 3.1 Row count + grain check (rows per order should be > order count)
SELECT
  COUNT(*)                       AS row_count,
  COUNT(DISTINCT order_id)       AS distinct_orders,
  ROUND(COUNT(*) / COUNT(DISTINCT order_id), 2) AS avg_items_per_order
FROM `olist-analytics-500708.olist_raw.order_items` 

-- 3.2 Null profile
select 
countif(product_id is null),
countif(seller_id is null),
countif(price is null),
countif(freight_value is null),
countif(shipping_limit_date is null) as null_ship_count
FROM `olist-analytics-500708.olist_raw.order_items` 

-- 3.3 Numeric range + quartiles for price and freight_value
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
FROM `olist-analytics-500708.olist_raw.order_items` 

-- 3.4 Items-per-order distribution (informs the order-grain aggregation)
SELECT items_per_order, COUNT(*) AS num_orders, 
 ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct_orders
FROM (
  SELECT order_id, COUNT(*) AS items_per_order
  FROM `olist-analytics-500708.olist_raw.order_items` 
  GROUP BY order_id
)
GROUP BY items_per_order
ORDER BY items_per_order;

SELECT
COUNTIF(price < 0) AS negative_price,
COUNTIF(freight_value < 0) AS negative_freight,
COUNTIF(freight_value=0) AS free_shipping,
min(shipping_limit_date) as min_ship_date,
max(shipping_limit_date) as max_ship_date
FROM `olist-analytics-500708.olist_raw.order_items` 

SELECT
    oi.order_id,
    o.order_purchase_timestamp,
    oi.shipping_limit_date
FROM `olist-analytics-500708.olist_raw.order_items` oi
JOIN `olist-analytics-500708.olist_raw.orders` o
USING(order_id)
WHERE oi.shipping_limit_date >= TIMESTAMP('2018-10-17')
ORDER BY oi.shipping_limit_date DESC;

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date
FROM `olist-analytics-500708.olist_raw.order_items` oi
JOIN `olist-analytics-500708.olist_raw.orders` o
USING(order_id)
WHERE oi.shipping_limit_date >= TIMESTAMP('2019-01-01');

SELECT
COUNT(*) AS affected_rows,
COUNT(DISTINCT order_id) AS affected_orders
FROM `olist-analytics-500708.olist_raw.order_items`
WHERE seller_id = '7a241947449cc45dbfda4f9d0798d9d0'
  AND shipping_limit_date >= TIMESTAMP('2019-01-01');

  SELECT
COUNT(*) total_rows
FROM `olist-analytics-500708.olist_raw.order_items`
WHERE seller_id='7a241947449cc45dbfda4f9d0798d9d0';