--Advanced SQL Analysis
--Change over time analysis
--Sales overtime by month for 4 years
--
--
SELECT
    DATETRUNC(Month, order_date) AS OrderDate,
    SUM(sales_amount) AS totalsales,
    COUNT(Distinct customer_key) AS totalcustomer,
    SUM(quantity) AS totalquantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(Month, order_date)
ORDER BY DATETRUNC(Month, order_date);

--Sales overtime by month for 4 years, However this way is more complicated
--
--
SELECT
    Year(order_date) AS OrderYEar,
    Month(order_date) AS OrderMonth,
    SUM(sales_amount) AS totalsales,
    COUNT(Distinct customer_key) AS totalcustomer,
    SUM(quantity) AS totalquantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY Year(order_date), Month(order_date)
ORDER BY Year(order_date), Month(order_date);

--Added date formating for better readability, However format changes the metrics 
--to string so it is unable to be ordered correctly
--
--
SELECT
    FORMAT(order_date, 'yyyy-MMM') AS OrderDate,
    SUM(sales_amount) AS totalsales,
    COUNT(Distinct customer_key) AS totalcustomer,
    SUM(quantity) AS totalquantity
FROM dbo.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM');

--Cumulative Analysis
--
--
SELECT
    orderdate,
    totalsales,
    SUM(totalsales)OVER(Partition by year(orderdate) ORDER BY orderdate) AS runningtotalsales,
    avgprice,
    AVG(avgprice)OVER(Partition by year(orderdate) ORDER BY orderdate) AS MovingAVG
FROM(
    SELECT
        DATETRUNC(Month, order_date) as orderdate,
        SUM(sales_amount) AS totalsales,
        AVG(price) AS avgprice
    FROM dbo.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY  DATETRUNC(Month, order_date)
)t;

--Performance Analysis
--comparing a certain value to a specific target
--Current Sales - Avg Sales
--Current Sales - Last year performance
--current sales - lowest sales performance

--Year over year analysis in comparison priduct sales to avg sales and previous year
--
--
WITH yearly_product_sales AS(
    SELECT
        YEAR(f.order_date) AS OrderYear,
        p.product_name,
        SUM(f.sales_amount) AS TotalSales
    FROM dbo.fact_sales f
    LEFT JOIN gold.dim_products p
    ON f.product_key = p.product_key
    WHERE YEAR(f.order_date) IS NOT NULL
    GROUP BY YEAR(f.order_date), p.product_name
)
SELECT
     orderYear,
     product_name,
     AVG(TotalSales) OVER(PARTITION BY product_name) AS AVGsales,
     Totalsales,
     Totalsales - AVG(TotalSales) OVER(PARTITION BY product_name) AS Diff,
     CASE  
        WHEN Totalsales - AVG(TotalSales) OVER(PARTITION BY product_name) > 0 THEN 'Above AVG'
        WHEN Totalsales - AVG(TotalSales) OVER(PARTITION BY product_name) < 0 THEN 'Bellow AVG'
        ELSE 'Average'
    END AVGDiff,
    LAG(TotalSales) OVER(PARTITION BY product_name ORDER BY orderYear) py_sales,
    TotalSales - LAG(TotalSales) OVER(PARTITION BY product_name ORDER BY orderYear) AS diffchange,
    CASE
        WHEN  LAG(TotalSales) OVER(PARTITION BY product_name ORDER BY orderYear) > 0 THEN 'More Sales'
        WHEN  LAG(TotalSales) OVER(PARTITION BY product_name ORDER BY orderYear) < 0 THEN 'Less Sales'
        ELSE 'Impass'
        END AS prDiff
FROM yearly_product_sales
ORDER BY product_name, OrderYear;

--Part to whole analysis
--checking a single meassure to a total measure * 100
--
--
WITH category_sales AS(
    SELECT
        p.category,
        SUM(f.sales_amount) AS totalSales
    FROM dbo.fact_sales f
    LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
    GROUP BY p.category
)
SELECT
    category,
    totalSales,
    SUM(totalSales)OVER() overal_sales,
    CONCAT(ROUND((CAST(totalsales AS FLOAT)/SUM(totalsales)OVER())  * 100,2), '%') AS '%'
FROM category_sales
ORDER BY '%' DESC;

--Data Segmentation
--group the data based on specific range
--finding corelation between 2 metrics
--Sales By sales range OR sales by Agegroup

--Show products in to cost range and how many product falls into the segment
--
--
WITH Product_Segment AS(
    SELECT  
        product_key,
        product_name,
        category,
        cost,
        CASE WHEN cost < 100 THEN 'Bellow 100'
        WHEN cost BETWEEN 100 AND 500 THEN '100-500'
        WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
        ELSE 'Above 1000'
        END costrange
    FROM gold.dim_products
)
SELECT
    costrange,
    Product_name,
    category,
    count(product_key) OVER(partition by category)AS totalproduct
FROM Product_Segment;
--GROUP BY costrange


--Group customer on segments based on their spending behavior
--
--
WITH Customer_Spending AS(
    SELECT
        c.customer_key,
        SUM(f.sales_amount) AS TotalSpend,
        MIN(order_date) AS FirstOrder,
        MAX(order_date) AS LastOrder,
        DATEDIFF(month, MIN(order_date),MAX(order_date)) AS LifeSpan
    FROM dbo.fact_sales f
    LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
    GROUP BY c.customer_key
)
SELECT
    customerSegment,
    COUNT(customer_key) AS totalcustomer
FROM(
    SELECT
        customer_key,
        CASE
            WHEN LifeSpan >= 12 AND TotalSpend >5000 THEN 'VIP'
            WHEN LifeSpan >= 12 AND TotalSpend <=5000 THEN 'Regular'
            else 'New Customer'
        END AS CustomerSegment
    FROM Customer_Spending
)t
GROUP BY CustomerSegment
ORDER BY totalcustomer DESC;

