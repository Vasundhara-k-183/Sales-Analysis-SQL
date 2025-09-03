


SELECT * FROM gold.fact_sales
select * from gold.dim_customers
select * from gold.dim_products

----SALES PERFORMANCE OVER TIME-----
SELECT 
YEAR(order_date) AS Order_Year , 
SUM(sales_amount) AS Total_sales,
COUNT(DISTINCT customer_key) AS Total_customers,
SUM(quantity) as Total_Qty
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date)


SELECT 
FORMAT (order_date , 'yyyy-MMM') AS Order_Date, 
SUM(sales_amount) AS Total_sales,
COUNT(DISTINCT customer_key) AS Total_customers,
SUM(quantity) as Total_Qty
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT (order_date , 'yyyy-MMM')
ORDER BY FORMAT (order_date , 'yyyy-MMM')


---Calculate total sales for each month and running total of sales over time

SELECT 
    Order_month, 
    Total_sales,
    SUM(Total_sales) OVER (PARTITION BY Order_month ORDER BY Order_month) AS Running_total
FROM (
    SELECT 
        DATETRUNC(MONTH, order_date) AS Order_month,
        SUM(Sales_Amount) AS Total_sales
    FROM GOLD.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
) t;
----------cummulative sum of sales over year-------
SELECT 
    Order_Year, 
    Total_sales,
    SUM(Total_sales) OVER ( ORDER BY Order_Year) AS Running_total
FROM (
    SELECT 
        DATETRUNC(YEAR, order_date) AS Order_Year,
        SUM(Sales_Amount) AS Total_sales
    FROM GOLD.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(YEAR, order_date)
) t;
---------moving average-----------

SELECT 
    Order_month, 
    Total_sales,
    SUM(Total_sales) OVER (ORDER BY Order_month) AS Running_total,
	AVG(Avg_price) OVER ( ORDER BY Order_month) AS moving_avg
FROM (
    SELECT 
        DATETRUNC(MONTH, order_date) AS Order_month,
        SUM(Sales_Amount) AS Total_sales,
		AVG(price) as Avg_price
    FROM GOLD.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(MONTH, order_date)
) t
---------------------Performance Analysis----------------
---Analyse the Yearly performance of product by comparing their  sales 
--to both avergge sales  of product and previous year sales 

WITH Yearly_product_Sales 
AS
(SELECT 
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS Current_sales 
FROM gold.fact_sales AS f
LEFT JOIN
gold.dim_products AS p
ON 
f.product_key= p.product_key
WHERE  F.order_date IS NOT NULL
GROUP BY YEAR(f.order_date),p.product_name) 
SELECT product_name,order_year,Current_sales,
AVG(Current_sales) OVER (PARTITION BY product_name) as Avg_sales,
current_sales - AVG(Current_sales) OVER (PARTITION BY product_name) as diff_avg,
CASE 
WHEN current_sales - AVG(Current_sales) OVER (PARTITION BY product_name) >0 THEN 'Above Avg'
WHEN current_sales - AVG(Current_sales) OVER (PARTITION BY product_name) <0 THEN 'Below Avg'
ELSE 'Avg'
END AS Avg_Change,
LAG(Current_Sales) OVER (PARTITION BY product_name ORDER BY order_year) as prev_sales,
Current_sales-LAG(Current_Sales) OVER (PARTITION BY product_name ORDER BY order_year) as diff_py,
CASE 
WHEN Current_sales-LAG(Current_Sales) OVER (PARTITION BY product_name ORDER BY order_year)>0 THEN 'Increase'
WHEN Current_sales-LAG(Current_Sales) OVER (PARTITION BY product_name ORDER BY order_year)<0 THEN 'Decrease'
ELSE 'No Change'
END AS py_change
FROM Yearly_product_Sales 
ORDER BY product_name,order_year


------------part to whole analysis ---------------

----which categories contributes to over all sales --

WITH category_sales 
AS
(SELECT
category,
SUM(sales_amount) AS total_sales 
FROM gold.fact_sales AS F
LEFT JOIN 
gold.dim_products as p 
ON f.product_key= p.product_key
GROUP BY category)
SELECT category ,
total_sales,
SUM(total_sales) OVER () AS overall_sales ,
CONCAT(ROUND((CAST(total_sales AS FLOAT)/SUM(total_sales) OVER () )*100,2),'%')as percent_of_total
FROM category_sales
ORDER BY total_sales DESC


------------category wise customer peercentage----
WITH category_cust AS (
    SELECT 
        p.category,
        COUNT(DISTINCT f.customer_key) AS total_customers
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_products AS p
        ON f.product_key = p.product_key
    WHERE f.customer_key IS NOT NULL
    GROUP BY p.category
),
all_customers_cte AS (
    SELECT COUNT(DISTINCT customer_key) AS all_customers
    FROM gold.fact_sales
)

SELECT 
    cc.category,
    cc.total_customers,
    ac.all_customers,
    CONCAT(
        ROUND(CAST(cc.total_customers AS FLOAT) / ac.all_customers * 100, 2),
        '%'
    ) AS percent_of_total_customers
FROM category_cust cc
CROSS JOIN all_customers_cte ac
ORDER BY cc.total_customers DESC;

--------------data segmentation------------------------

---segment products in cost range and count how many products fall into each segment--

WITH Product_segment 
AS
(SELECT 
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
     WHEN Cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'ABOVE 1000'
	 END AS Cost_range 
FROM gold.dim_products)

SELECT cost_range ,
	   COUNT(product_key) as product_count
	   FROM Product_segment
	   GROUP BY cost_range 
	   ORDER BY product_count DESC


------------GROUP the customers based on their spending behaviour--
---VIP Atleast  12 months of history and spending more than 5000
----Regular  Atleast 12 months of history and spending 5000  or less
--NEW - Lifespan less than 12 months
--and find total number of customers for each group


WITH Customer_Spending 
AS
(SELECT 
c.customer_key,
SUM(f.sales_amount) AS Total_spend,
MIN(f.order_date)AS first_order_date,
MAX(F.order_date) AS last_order_date,
DATEDIFF(MONTH,MIN(f.order_date),MAX(F.order_date)) AS Lifespan
FROM gold.fact_sales AS f
LEFT JOIN 
gold.dim_customers AS c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key) 

SELECT 
customer_segments ,
COUNT(customer_key) AS Total_customers

FROM(
SELECT 
      customer_key ,
CASE WHEN Lifespan >=12 AND total_spend > 5000 THEN 'VIP'
     WHEN Lifespan >=12 AND total_spend <= 5000 THEN 'Regular'
	 ELSE 'New'
	 END AS Customer_Segments
FROM Customer_Spending ) T
GROUP BY  Customer_segments
ORDER BY Total_customers DESC

/*=====================================================================================================
                              CUSTOMER REPORT
=======================================================================================================
Purpose: This report consolidates  key customer behaviours

Highlights :
  1. Gathers essential fileds such as names, ages, nd transaction details.
  2. Segments customers into categories (VIP, Regular, New) and Age Groups.
  3.Aggregates customer-level; metrics:
   - total sales
   - total orders
   - total quantity purchased
   - total products
   - life span
 4. Calculates valuable KPI's:
   - recency (months since last order)
   - average order value
   - average monthly spend
============================================================================================================*/

/*-----------------------------------------------------------------------------------------------------------
1. Base Query : Retreving core columns from tables
-----------------------------------------------------------------------------------------------------------*/

GO
CREATE VIEW gold.customer_report AS 

-- 1. Base Query: Retrieving core columns from tables
  WITH Base_Query AS (
    SELECT 
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS Age
    FROM gold.fact_sales AS f
    LEFT JOIN gold.dim_customers AS c
        ON f.customer_key = c.customer_key
    WHERE f.order_date IS NOT NULL
),

-- 2. Customer-Level Aggregation
Customer_Aggregation AS (
    SELECT 
        customer_key,
        customer_name,
        customer_number,
        Age,
        SUM(sales_amount) AS Total_Sales,
        COUNT(DISTINCT order_number) AS Total_orders,
        SUM(quantity) AS Total_qty,
        MAX(order_date) AS Last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS Lifespan
    FROM Base_Query
    GROUP BY 
        customer_key,
        customer_name,
        customer_number,
        Age
)

-- 3. Final Output with Segmentation
SELECT 
    customer_key,
    customer_name,
    customer_number,
    Age,

    -- Age grouping
    CASE 
        WHEN Age < 20 THEN 'Below 20'
        WHEN Age BETWEEN 20 AND 29 THEN '20-29'
        WHEN Age BETWEEN 30 AND 39 THEN '30-39'
        WHEN Age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 AND ABOVE'
    END AS Age_group,

    -- Customer segment classification
    CASE 
        WHEN Lifespan >= 12 AND Total_Sales > 5000 THEN 'VIP'
        WHEN Lifespan >= 12 AND Total_Sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS Customer_Segments,
	Last_order_date,
	DATEDIFF(MONTH , Last_order_date ,GETDATE()) AS Recency,
    Total_Sales,
    Total_orders,
    Total_qty,
    Lifespan,
	--compute avg order value(AVO)
	CASE 
	WHEN Total_orders = 0 THEN 0 
	ELSE 
	Total_Sales/Total_orders
	END  AS  Average_order_value,
	--COMPUTE total average spend 
	CASE 
	WHEN lifespan = 0  THEN lifespan
	ELSE 
	Total_Sales / lifespan 
	END AS Total_avg_spend

FROM Customer_Aggregation;
GO

SELECT * FROM gold.customer_report

/*=================================================================================================================================
                                      PRODUCT REPORT
====================================================================================================================================
Purpose:  This report consolidates key product metrics and behaviours.

Highlights:
1. Gathers essential fields such as product name ,category ,subcategory  and cost .
2. Segments products by revenue to identify high performers , mid-range , or low performer.
3.Aggregates product- level metrics :
 - total orders
 - total sales
 - total quantity sold
 - total customers(unique)
 - lifespan(in months) 
4. Calculates valuable KPI's :
 - recency (months since last sales)
 - average order revenue (AOR)
 - average monthly revenue
 ====================================================================================================================================*/
/*
------------------------------------------------------------------------------------------
1. Base_Prod_Query : Retreving core columns from tables
-----------------------------------------------------------------------------------------------------*/
GO 
CREATE VIEW  gold.product_report 
AS

WITH 
Base_Prod_Query AS (
    SELECT 
        f.order_number,
        f.order_date,
        f.sales_amount,
        f.quantity,
        f.customer_key,
        p.category,
        p.cost,
        p.product_key,
        p.subcategory,
        p.product_name
    FROM 
        gold.fact_sales AS f
    LEFT JOIN
        gold.dim_products AS p
    ON f.product_key = p.product_key
),

Product_Aggregation AS (
    SELECT 
        category,
        subcategory, 
        product_name,
        product_key,
        COUNT(DISTINCT order_number) AS Total_order,
        MIN(order_date) AS First_Order_Date,
        MAX(order_date) AS Last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS Lifespan,
        SUM(sales_amount) AS Total_Sales,
        SUM(quantity) AS Total_Qty,
        COUNT(DISTINCT customer_key) AS Total_customers,
        SUM(cost * quantity) AS Total_cost
    FROM 
        Base_Prod_Query
    GROUP BY 
        category,
        subcategory, 
        product_name,
        product_key
)

SELECT 
    category,
    subcategory, 
    product_name,
    product_key,
    Total_order,
    Total_Sales,
    Lifespan,
    Last_order_date,
    DATEDIFF(MONTH, Last_order_date, GETDATE()) AS Recency,
    
    -- Revenue Segmentation
    CASE 
        WHEN Total_Sales > 1000000 THEN 'High Performer'
        WHEN Total_Sales BETWEEN 500000 AND 1000000 THEN 'Mid-Range'
        ELSE 'Low Range'
    END AS Revenue_Segment,

    -- AOR
    CAST(ROUND(CASE 
        WHEN Total_order = 0 THEN 0
        ELSE Total_Sales * 1.0 / Total_order
    END,2) AS DECIMAL(10,2))AS AVG_Order_Revenue,

    -- Avg Monthly Revenue
    CAST(ROUND(CASE 
        WHEN Lifespan = 0 THEN 0
        ELSE Total_Sales * 1.0 / Lifespan
    END,2)AS DECIMAL(10,2)) AS Avg_Monthly_Revenue

FROM
    Product_Aggregation
GO


SELECT * FROM gold.product_report
