select * from [dbo].[Flipkart_Customer]
select * from [dbo].[Flipkart_Orderdetails]
select * from [dbo].[Flipkart_Orders]
select * from [dbo].[Flipkart_Products]
select * from [dbo].[Flipkart_Returns]

--Total revenue generated per month in the last 12 months
SELECT 
    FORMAT(order_date, 'yyyy-MM') AS Month,
    SUM(total_amount) AS Total_Revenue
FROM Flipkart_orders
WHERE order_date >= DATEADD(MONTH, -12, GETDATE())
GROUP BY FORMAT(order_date, 'yyyy-MM')
ORDER BY Month;
--Which products and categories contribute the most to revenue?
SELECT 
    p.category,
    p.product_id,
    SUM(od.quantity * p.price * (1 - 
        CAST(REPLACE(od.discount, '%', '') AS FLOAT) / 100.0
    )) AS Revenue
FROM Flipkart_Orderdetails od
JOIN Flipkart_Products p 
    ON od.product_id = p.product_id
GROUP BY p.category, p.product_id
ORDER BY Revenue DESC;

--Average order value (AOV) across different regions
SELECT 
    c.Country AS Region,
    AVG(CAST(o.total_amount AS DECIMAL(18,2))) AS Avg_Order_Value
FROM flipkart_Orders o
JOIN flipkart_Customer c ON o.customer_id = c.customer_id
GROUP BY c.Country
ORDER BY Avg_Order_Value DESC;

--Who are the top 10 customers by lifetime value?
SELECT TOP 10
    c.customer_id,
    c.First_name,
	c.last_name,
    SUM(o.total_amount) AS Lifetime_Value
FROM flipkart_Orders o
JOIN flipkart_Customer c ON o.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name,c.last_name
ORDER BY Lifetime_Value DESC;

--New Customers per Month
SELECT 
    FORMAT(join_date, 'yyyy-MM') AS Month,
    COUNT(customer_id) AS New_Customers
FROM flipkart_Customer
GROUP BY FORMAT(join_date, 'yyyy-MM')
ORDER BY Month;

--Repeat Buyers vs. One-Time Buyers
WITH CustomerOrders AS (
    SELECT customer_id, COUNT(order_id) AS OrderCount
    FROM flipkart_Orders
    GROUP BY customer_id
)
SELECT 
    SUM(CASE WHEN OrderCount = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS OneTime_Percentage,
    SUM(CASE WHEN OrderCount > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS Repeat_Percentage
FROM CustomerOrders;

--Revenue by Customer Segment (Gender / Location)
SELECT 
    c.gender,
    c.country,
    SUM(o.total_amount) AS Revenue
FROM flipkart_Orders o
JOIN flipkart_Customer c ON o.customer_id = c.customer_id
GROUP BY c.gender, c.country
ORDER BY Revenue DESC;

--Average Purchase Frequency per Customer
SELECT 
    AVG(OrderCount) AS Avg_Purchase_Frequency
FROM (
    SELECT customer_id, COUNT(order_id) AS OrderCount
    FROM flipkart_Orders
    GROUP BY customer_id
) t;

--Customers at Risk of Churn (no purchase in last 6 months)
SELECT 
    c.customer_id,
    c.first_name,
    MAX(o.order_date) AS Last_Order_Date
FROM flipkart_Customer c
LEFT JOIN flipkart_Orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, c.first_name
HAVING MAX(o.order_date) < DATEADD(MONTH, -6, GETDATE())
   OR MAX(o.order_date) IS NULL;

--Which products have the highest return rate (returns/orders ratio)?
SELECT 
    p.product_id,
    p.brand,
    CONCAT(CAST(ROUND(COUNT(r.return_id) * 100.0 / COUNT(DISTINCT od.order_id), 0) AS INT), '%') AS Return_Rate
FROM Flipkart_Products p
JOIN Flipkart_Orderdetails od ON p.product_id = od.product_id
LEFT JOIN Flipkart_Returns r ON od.order_id = r.order_id
GROUP BY p.product_id, p.brand
ORDER BY ROUND(COUNT(r.return_id) * 100.0 / COUNT(DISTINCT od.order_id), 0) DESC;

--What is the most frequently bought product bundle (products often purchased together)?
SELECT 
    od1.product_id AS Product_A,
    od2.product_id AS Product_B,
    COUNT(*) AS Frequency
FROM Flipkart_Orderdetails od1
JOIN Flipkart_Orderdetails od2 
    ON od1.order_id = od2.order_id AND od1.product_id < od2.product_id
GROUP BY od1.product_id, od2.product_id
ORDER BY Frequency DESC;

--Which products generate the highest profit margins (price – discount)?
SELECT 
    p.product_id,
	p.category,
	p.brand,
    SUM(od.quantity * 
        (p.price - (p.price * CAST(REPLACE(od.discount, '%', '') AS FLOAT)/100.0))
    ) AS Profit_Margin
FROM Flipkart_Orderdetails od
JOIN Flipkart_Products p ON od.product_id = p.product_id
GROUP BY p.product_id, p.category, p.brand
ORDER BY Profit_Margin DESC;

--Which categories have low sales but high return rates?
WITH CategoryStats AS (
    SELECT 
        p.category,
        SUM(od.quantity) AS Total_Sales,
        COUNT(r.return_id) * 1.0 / NULLIF(COUNT(DISTINCT od.order_id),0) AS Return_Rate
    FROM Flipkart_Products p
    JOIN Flipkart_Orderdetails od ON p.product_id = od.product_id
    LEFT JOIN Flipkart_Returns r ON od.order_id = r.order_id
    GROUP BY p.category
)
SELECT 
    category,
    Total_Sales,
    CONCAT(CAST(ROUND(Return_Rate * 100, 0) AS INT), '%') AS Return_Rate
FROM CategoryStats
WHERE Total_Sales < (SELECT AVG(Total_Sales) FROM CategoryStats)
  AND Return_Rate > (SELECT AVG(Return_Rate) FROM CategoryStats)
ORDER BY Return_Rate DESC;

--Are there seasonal spikes in demand for certain categories?
SELECT 
    p.category,
    FORMAT(o.order_date, 'yyyy-MM') AS Month,
    SUM(od.quantity) AS Total_Sales
FROM Flipkart_Orderdetails od
JOIN Flipkart_Orders o ON od.order_id = o.order_id
JOIN Flipkart_Products p ON od.product_id = p.product_id
GROUP BY p.category, FORMAT(o.order_date, 'yyyy-MM')
ORDER BY p.category, Month;

--Which regions or customer segments have the highest return rates?
SELECT 
    c.country,
    FORMAT(COUNT(r.return_id) * 100.0 / COUNT(o.order_id), 'N2') + '%' AS Return_Rate
FROM Flipkart_Customer c
JOIN Flipkart_Orders o ON c.customer_id = o.customer_id
LEFT JOIN Flipkart_Returns r ON o.order_id = r.order_id
GROUP BY c.country
ORDER BY COUNT(r.return_id) * 100.0 / COUNT(o.order_id) DESC;

--What are the top 5 reasons for returns?
SELECT TOP 5 
    Reason,
    COUNT(*) AS Count
FROM Flipkart_Returns
GROUP BY Reason
ORDER BY Count DESC;

--Which products or brands are most frequently refunded?
SELECT 
    p.brand,
    COUNT(r.return_id) AS Refund_Count
FROM Flipkart_Returns r
JOIN Flipkart_Orderdetails od ON r.order_id = od.order_id
JOIN Flipkart_Products p ON od.product_id = p.product_id
GROUP BY p.brand
ORDER BY Refund_Count DESC;

--Distribution of Payment Methods
SELECT 
    payment_mode,
    COUNT(order_id) AS Order_Count,
    CONCAT(CAST(ROUND(COUNT(order_id) * 100.0 / (SELECT COUNT(*) FROM Flipkart_Orders), 0) AS INT), '%') AS Percentage
FROM Flipkart_Orders
GROUP BY payment_mode
ORDER BY Order_Count DESC;

--High-Value vs. Low-Value Payment Methods
SELECT 
    payment_mode,
    CASE WHEN total_amount >= 5000 THEN 'High Value' ELSE 'Low Value' END AS Order_Type,
    COUNT(order_id) AS Orders
FROM Flipkart_Orders
GROUP BY payment_mode,
         CASE WHEN total_amount >= 5000 THEN 'High Value' ELSE 'Low Value' END
ORDER BY payment_mode;

--Lowest Return Rate by Payment Method
SELECT 
    o.payment_mode,
    CONCAT(CAST(ROUND(COUNT(r.return_id) * 100.0 / COUNT(o.order_id), 2) AS DECIMAL(5,2)), '%') AS Return_Rate
FROM Flipkart_Orders o
LEFT JOIN Flipkart_Returns r ON o.order_id = r.order_id
GROUP BY o.payment_mode
ORDER BY COUNT(r.return_id) * 1.0 / COUNT(o.order_id);

--Highest Sales by Region/State/City
SELECT 
	c.Country,
	c.City,
    SUM(o.total_amount) AS Total_Sales
FROM Flipkart_Orders o
JOIN Flipkart_Customer c ON o.customer_id = c.customer_id
GROUP BY  c.Country, c.City
ORDER BY Country desc;

--Average Order Value by Location
SELECT 
    c.City,
    CAST(AVG(CAST(o.total_amount AS DECIMAL(18,2))) AS INT) AS Avg_Order_Value
FROM Flipkart_Orders o
JOIN Flipkart_Customer c ON o.customer_id = c.customer_id
GROUP BY c.city
ORDER BY Avg_Order_Value DESC;
 
 -- Location-Specific Product Preferences
 SELECT 
    c.City,
    p.Category,
    COUNT(od.order_id) AS Orders
FROM Flipkart_Orderdetails od
JOIN Flipkart_Orders o ON od.order_id = o.order_id
JOIN Flipkart_Customer c ON o.customer_id = c.customer_id
JOIN Flipkart_Products p ON od.product_id = p.product_id
GROUP BY c.city, p.category
ORDER BY Orders DESC;

--Highest Return % by Location
SELECT 
    c.City,
	c.Country,
    CONCAT(CAST(ROUND(COUNT(r.return_id) * 100.0 / COUNT(o.order_id), 2) AS DECIMAL(5,2)), '%') AS Return_Rate
FROM Flipkart_Customer c
JOIN Flipkart_Orders o ON c.customer_id = o.customer_id
LEFT JOIN Flipkart_Returns r ON o.order_id = r.order_id
GROUP BY c.City, c.Country
ORDER BY Return_Rate DESC;

--Fastest Growing Regions (Customer Growth in 12 Months)
SELECT 
    c.Country,
    c.City,
    FORMAT(c.join_date, 'yyyy-MM') AS Month,
    COUNT(c.customer_id) AS New_Customers
FROM Flipkart_Customer c
WHERE c.join_date >= DATEADD(MONTH, -12, GETDATE())
GROUP BY c.Country, c.City, FORMAT(c.join_date, 'yyyy-MM')
ORDER BY c.Country, Month;


