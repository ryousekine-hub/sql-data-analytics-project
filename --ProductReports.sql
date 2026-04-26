--ProductReports
--make the product Report
--CREATE VIEW gold.report_product AS
WITH base_query AS(
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost,
        COUNT(DISTINCT f.order_number) AS total_order,
        SUM(f.sales_amount) AS total_sale,
        SUM(f.quantity) AS total_quantity,
        COUNT(DISTINCT f.customer_key) AS total_unique_customer,
        DATEDIFF(month, MIN(f.order_date),MAX(f.order_date)) AS life_span,
        MAX(f.order_date) AS last_sale_date,
        ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)),1) AS AVG_price
    FROM dbo.fact_sales f
    LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
    WHERE order_date IS NOT NULL
    GROUP BY 
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
)
SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    last_sale_date,
    DATEDIFF(month, last_sale_date, GETDATE()) AS sale_recency_month,
    CASE
        WHEN total_sale >= 100000 THEN 'High Performer'
        WHEN total_sale >= 5000 THEN 'Medium Performer'
        ELSE 'Low Performer'
        END product_performance_segment,
    total_sale,
    total_order,
    total_quantity,
    AVG_price,
    CASE WHEN total_order = 0 THEN 0
        ELSE total_sale / total_order
    END AS Average_Order_Value,
    life_span,
    CASE WHEN life_span = 0 THEN total_sale
        ELSE total_sale /life_span 
    END AS AverageMonthlyRevenue
FROM base_query