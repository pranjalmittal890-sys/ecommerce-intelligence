select count(*) as cnt_row,
count(distinct product_id) as product_cnt
from `olist-analytics-500708.olist_raw.products`

SELECT
  COUNTIF(product_category_name IS NULL)   AS null_category,
  round(COUNTIF(product_category_name IS NULL)/count(*)*100,2) as null_category_pcnt,
  COUNTIF(product_weight_g IS NULL)        AS null_weight,
  COUNTIF(product_length_cm IS NULL)       AS null_length,
  COUNTIF(product_height_cm IS NULL)       AS null_height,
  COUNTIF(product_width_cm IS NULL)        AS null_width,
  COUNTIF(product_photos_qty IS NULL)      AS null_photos_qty
from `olist-analytics-500708.olist_raw.products`

-- 6.3 Category cardinality + top categories
SELECT
  COUNT(DISTINCT product_category_name) AS distinct_categories
  from `olist-analytics-500708.olist_raw.products`

-- 6.4 Weight/dimension range (sanity check for zero/negative/absurd values)
SELECT
  MIN(product_weight_g) AS min_weight, MAX(product_weight_g) AS max_weight,
  COUNTIF(product_weight_g = 0) AS zero_weight_count
from `olist-analytics-500708.olist_raw.products`

SELECT
  MIN(product_length_cm) AS min_length, MAX(product_length_cm) AS max_length,
  MIN(product_height_cm) AS min_height, MAX(product_height_cm) AS max_height,
  MIN(product_width_cm) AS min_width, MAX(product_width_cm) AS max_width
from `olist-analytics-500708.olist_raw.products`

select product_category_name, count(*) as cnt
from `olist-analytics-500708.olist_raw.products`
group by product_category_name
order by cnt desc limit 10

select MIN(product_description_lenght) AS min_length, 
MAX(product_description_lenght) AS max_length,
min(product_name_lenght) AS min_name_length, 
MAX(product_name_lenght) AS max_name_length,
min(product_photos_qty) as min_photos_qty, 
max(product_photos_qty) as max_photos_qty
from `olist-analytics-500708.olist_raw.products`

select distinct product_id
from `olist-analytics-500708.olist_raw.order_items`
where product_id in (
  select product_id from `olist-analytics-500708.olist_raw.products` where product_category_name is null)

SELECT
APPROX_QUANTILES(product_weight_g,2)[OFFSET(1)]
FROM `olist-analytics-500708.olist_raw.products`
WHERE product_category_name='cama_mesa_banho'
AND product_weight_g>0;

