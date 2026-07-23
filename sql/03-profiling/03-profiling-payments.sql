SELECT count(*) as row_cnt, 
count(distinct order_id) as order_cnt,
round(avg(payment_value),2) as avg_payment_value,
round(COUNT(*) / COUNT(DISTINCT order_id),2) as avg_payment_per_order
FROM `olist-analytics-500708.olist_raw.order_payments`

select payment_per_order, count(*) as n
from (
  select order_id, count(*) as payment_per_order
  from `olist-analytics-500708.olist_raw.order_payments`
  group by order_id
)
group by payment_per_order
order by 1

-- 4.2 payment_type frequency
select payment_type, count(*) as cnt,
round(count(*)/sum(count(*)) over() * 100,2) as pcnt
FROM `olist-analytics-500708.olist_raw.order_payments`
group by payment_type
order by pcnt desc

-- 4.3 payment_installments range + distribution
select min(payment_installments) as min_pymt,
max(payment_installments) as max_pymt,
approx_quantiles(payment_installments,4) as quartiles
FROM `olist-analytics-500708.olist_raw.order_payments`

-- 4.4 payment_value range + quartiles
SELECT
  MIN(payment_value) AS min_val, MAX(payment_value) AS max_val,
  ROUND(AVG(payment_value), 2) AS avg_val,
  APPROX_QUANTILES(payment_value, 4) AS quartiles,
  COUNTIF(payment_value < 0) AS non_positive_count
FROM `olist-analytics-500708.olist_raw.order_payments`

select *
from `olist-analytics-500708.olist_raw.order_payments`
where payment_value<=0

select *
from `olist-analytics-500708.olist_raw.order_payments`
where order_id='a4431cbd79dbddaae7988ce6091cbc3c'

select
countif(order_id is null) as order_id_null_cnt,
countif(payment_sequential is null) as payment_sequential_null_cnt,
countif(payment_type is null) as payment_type_null_cnt,
countif(payment_installments is null) as payment_installments_null_cnt,
countif(payment_value is null) as payment_value
from `olist-analytics-500708.olist_raw.order_payments`

-- Payment Sequential Validation
SELECT
order_id,
MAX(payment_sequential) AS max_seq,
COUNT(*) AS payment_rows
FROM `olist-analytics-500708.olist_raw.order_payments`
GROUP BY order_id
HAVING MAX(payment_sequential) != COUNT(*);

-- installment validation
SELECT
payment_type,
payment_installments,
COUNT(*) AS n
FROM `olist-analytics-500708.olist_raw.order_payments`
WHERE payment_installments = 0
GROUP BY 1,2;

SELECT *
FROM `olist-analytics-500708.olist_raw.orders`
WHERE order_id NOT IN (
SELECT DISTINCT order_id
FROM `olist-analytics-500708.olist_raw.order_payments`
);

SELECT
    order_id,
    ARRAY_AGG(payment_sequential ORDER BY payment_sequential) AS sequences,
    COUNT(*) AS payment_rows,
    MAX(payment_sequential) AS max_seq
FROM `olist-analytics-500708.olist_raw.order_payments`
GROUP BY order_id
HAVING COUNT(*) != MAX(payment_sequential)
LIMIT 20;


