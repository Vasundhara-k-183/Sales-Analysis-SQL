# Sales Analytics SQL Portfolio (Gold Schema)

A compact, production-style SQL project that builds reusable views and analyses for retail sales, customers, and products. It demonstrates time-series KPIs, part‑to‑whole breakdowns, segmentation logic, and window‑function techniques—ready to plug into BI tools like Power BI or Tableau.

---

## 🔍 What this project does

* **Explores sales performance over time** (yearly and monthly) and computes **running totals** and a **running average** of price.
* **Benchmarks product performance** against product-wide averages and **year‑over‑year (YoY)** changes using window functions.
* Performs **part‑to‑whole** analysis to show category contribution to overall sales and **share of customers by category**.
* **Segments products by cost** brackets and **segments customers** by spend & lifecycle (VIP / Regular / New).
* **Creates two reusable views**:

  * `gold.customer_report` — consolidated customer‑level KPIs
  * `gold.product_report` — consolidated product‑level KPIs

> **Tech:** Microsoft SQL Server 2022+ (uses `DATETRUNC`, `FORMAT`, window functions), T‑SQL.

---

## 📦 Source tables (expected)

Schema: `gold`

* `fact_sales` — transactional facts: `order_number`, `order_date`, `sales_amount`, `quantity`, `customer_key`, `product_key`.
* `dim_customers` — customer attributes: `customer_key`, `customer_number`, names, `birthdate`.
* `dim_products` — product attributes: `product_key`, `product_name`, `category`, `subcategory`, `cost`.

> The script assumes these tables already exist in the `gold` schema.

---

## 🧮 Analyses & Logic

### 1) Sales performance over time

* Yearly and month buckets from `order_date` with totals: **sales, customers, quantity**.
* **Running totals** by month/year for cumulative trends.
* **Running average** of average price over time.

**Example (monthly view)**

```sql
SELECT
  DATETRUNC(MONTH, order_date) AS order_month,
  SUM(sales_amount)            AS total_sales,
  SUM(total_sales) OVER (ORDER BY DATETRUNC(MONTH, order_date)) AS running_total
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date);
```

---

### 2) Product performance benchmarking

For each product & year:

* Compare **current sales vs product average** (flag Above/Below Avg).
* Compute **previous year sales** and **YoY difference** (Increase/Decrease/No Change).

Key window functions: `AVG() OVER (PARTITION BY product_name)`, `LAG() OVER (PARTITION BY product_name ORDER BY order_year)`.

---

### 3) Part‑to‑whole: category contribution

* Category‑level totals with **overall total** via `SUM(...) OVER ()`.
* Compute **% of total sales** per category.

---

### 4) Customer share by category

* Distinct **customer counts per category** vs **all unique customers**, returning **% of total customers** engaging each category.

---

### 5) Segmentation

**Product cost segments**

* `< 100`, `100–500`, `500–1000`, `> 1000` → product counts per band.

**Customer segments**

* **VIP:** lifespan ≥ 12 months **and** total spend > 5000
* **Regular:** lifespan ≥ 12 months **and** total spend ≤ 5000
* **New:** lifespan < 12 months

Lifespan is computed in **months** between first and last order.

---

## 🧱 Views created

### `gold.customer_report`

Consolidated customer‑level KPIs and attributes:

* Identity: `customer_key`, `customer_number`, `customer_name`, **Age** (computed from `birthdate`).
* **Age group** buckets: `<20`, `20–29`, `30–39`, `40–49`, `50+`.
* **Customer segment:** VIP / Regular / New (see logic above).
* Activity: `Last_order_date`, **Recency** (months since last order), **Lifespan** (months active).
* Volume & value: `Total_Sales`, `Total_orders`, `Total_qty`.
* **Average Order Value (AOV)** = `Total_Sales / Total_orders` (safe divide).
* **Avg Monthly Spend** = `Total_Sales / Lifespan` (safe divide).

> This view is ideal for RFM‑style dashboards, churn monitoring, and cohort analysis.

---

### `gold.product_report`

Consolidated product‑level KPIs and attributes:

* Identity: `product_key`, `product_name`, `category`, `subcategory`.
* Activity: `Total_order`, `First_Order_Date`, `Last_order_date`, **Lifespan** (months), **Recency** (months since last sale).
* Volume & value: `Total_Sales`, `Total_Qty`, `Total_customers`, `Total_cost`.
* **Revenue segment** tiers:

  * **High Performer:** `Total_Sales > 1,000,000`
  * **Mid‑Range:** `500,000–1,000,000`
  * **Low Range:** otherwise
* **Average Order Revenue (AOR)** = `Total_Sales / Total_order` (rounded).
* **Avg Monthly Revenue** = `Total_Sales / Lifespan` (rounded).

> Use this view for Pareto analyses, assortment optimization, and lifecycle tracking.

---

## 🚀 Getting started

### Prerequisites

* **SQL Server 2022 or Azure SQL** (script uses `DATETRUNC` & `FORMAT`).
* Existing `gold` schema with the three tables populated.

### Run the project

1. Open the `.sql` file in SSMS / Azure Data Studio.
2. Execute the script (it contains **idempotent** read queries and **CREATE VIEW** statements separated by `GO`).
3. Validate the views:

   ```sql
   SELECT TOP (50) * FROM gold.customer_report;
   SELECT TOP (50) * FROM gold.product_report;
   ```

### Plug into BI

* Connect your BI tool to SQL and point visuals to the two views for quick, consistent KPIs.

---

## 🧪 Example questions this answers

* How are **sales trending** month‑over‑month? What’s the **running total**?
* Which products are **above/below their average** and how did they change **YoY**?
* Which categories contribute the **largest share** of sales and **customers**?
* Which customers are **VIP vs Regular vs New**, and what is their **recency** and **AOV**?
* Which products are **High Performers** and what’s their **AOR** and **Avg Monthly Revenue**?

---


## 🔧 Configuration knobs (optional)

* **Customer segment thresholds:** change the `5000` spend cutoff or `12` months lifespan.
* **Revenue segment bands:** adjust `1,000,000` and `500,000` as needed.
* **Cost segment bands:** update the CASE ranges.

---

## 📈 Next steps

* Add **tests** (row counts, NOT NULL checks) to validate sources.
* Parameterize thresholds via a **config table**.
* Create **indexes** on `order_date`, `customer_key`, `product_key` to speed up reads.
* Add **cohort** and **retention** queries, and a **calendar** dimension for robust time logic.

---

## 🙌 Credits

Built from a single, well‑organized SQL script that layers analyses and builds durable reporting views for customers and products.
