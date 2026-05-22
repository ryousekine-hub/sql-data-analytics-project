--CustomerReports
--CREATE customer reports
--
CREATE VIEW gold.report_customer AS
--CREATE VIEW is to create a view in the database to make this querry bellow be viewed outside of this sql doc
--From here the report is ready to be pipelined to Tableau PowerBI or other visualization tool
--you can call the view on a simple select * FROM gold.report_customer
WITH base_query AS(
    --THIS IS THE BASE QUERRY should transform the data like age or nulls
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(first_name, ' ', last_name) CustomerName,
        DATEDIFF(year, c.birthdate, getdate()) Age
    FROM dbo.fact_sales f
    LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
    WHERE order_date IS NOT NULL
)
,customer_aggregation AS (
    --aggregate all the data than can be aggreagated for addition insight
    SELECT 
        customer_key,
        customer_number,
        CustomerName,
        Age,
        COUNT(DISTINCT order_number) AS total_order,
        SUM(sales_amount) AS total_sale,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_product,
        MAX(order_date) AS last_order,
        DATEDIFF(month, MIN(order_date),MAX(order_date)) AS LifeSpan
    FROM base_query
    GROUP BY customer_key, customer_number, CustomerName, Age
)
SELECT
    customer_key,
    customer_number,
    CustomerName,
    Age,
    LifeSpan,
    CASE
        WHEN AGE < 20 THEN 'under 20'
        WHEN AGE BETWEEN 20 AND 29 THEN '20-29'
        WHEN AGE between 30 AND 39 THEN '30-39'
        WHEN AGe between 40 AND 49 THEN '40-49'
        ELSE '>50'
    END AgeSegment,
    CASE
        WHEN LifeSpan >= 12 AND total_sale >5000 THEN 'VIP'
        WHEN LifeSpan >= 12 AND total_sale <=5000 THEN 'Regular'
        else 'New Customer'
     END  CustomerSegment,
     last_order,
     DATEDIFF(month, last_order, GETDATE()) Recency,
    total_order,
    total_sale,
    total_quantity,
    total_product,
    CASE WHEN total_order = 0 THEN 0
        ELSE total_sale / total_order
    END AS AVG_Value_Order,
    CASE WHEN LifeSpan = 0 THEN total_sale
        ELSE total_sale / LifeSpan
    END AVG_Montly_Spend
FROM customer_aggregation
