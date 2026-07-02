## Inputs
- Kaggle: [Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce/data) — 9 CSV files.
- A Google account (for BigQuery sandbox).

## Step-by-step

### 1. BigQuery sandbox
1. Go to `console.cloud.google.com` → sign in → accept terms.
2. Create a new project, e.g. `olist-analytics-500708`.
3. Open **BigQuery** from the console menu. The free **sandbox** gives 10 GB storage + 1 TB query/month — far more than Olist needs.

### 2. Create datasets
In the BigQuery SQL editor, run:
```sql
CREATE SCHEMA IF NOT EXISTS `olist-analytics-500708.olist_raw`     OPTIONS(location='US');
CREATE SCHEMA IF NOT EXISTS `olist-analytics-500708.olist_clean`   OPTIONS(location='US');
CREATE SCHEMA IF NOT EXISTS `olist-analytics-500708.olist_serving` OPTIONS(location='US');
```
(Replace `olist-analytics-500708` with your actual project id everywhere.)

### 3. Load the 9 CSVs
For each file: BigQuery → `olist_raw` dataset → **Create table** → Source = Upload → pick CSV → Table name as below → Schema = **Auto detect** → Header rows to skip = 1.

| CSV file | Raw table name |
|---|---|
| olist_customers_dataset.csv | `customers` |
| olist_orders_dataset.csv | `orders` |
| olist_order_items_dataset.csv | `order_items` |
| olist_order_payments_dataset.csv | `order_payments` |
| olist_order_reviews_dataset.csv | `order_reviews` |
| olist_products_dataset.csv | `products` |
| olist_sellers_dataset.csv | `sellers` |
| olist_geolocation_dataset.csv | `geolocation` |
| product_category_name_translation.csv | `category_translation` |

> Note: auto-detect may type timestamp columns as STRING. That's fine for raw landing — we parse them properly in the clean layer, per the "raw stays raw" principle.