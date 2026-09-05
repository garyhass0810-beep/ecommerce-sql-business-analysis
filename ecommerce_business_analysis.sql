-- =====================================================
-- E-COMMERCE BUSINESS & PRODUCT ANALYSIS
-- SQL Portfolio Project
-- =====================================================
-- Objective:
-- Analyze customer behavior, sales performance,
-- product performance, and operational efficiency
-- to identify actionable business insights.
--
-- Approach:
-- Each question starts with a business problem and explains
-- why the SQL was structured the way it was. The goal is to
-- show not only the final query, but also the reasoning behind it.
-- =====================================================

USE ecommerce;


-- =====================================================
-- 1. CUSTOMER ANALYSIS
-- =====================================================

-- Q1: How many registered users are there, and how many are currently active?
--
-- Approach:
-- I wanted a quick snapshot of the size of the customer base and how much of it
-- is currently active. COUNT(*) gives the total number of registered users.
-- Since is_active is stored as 1 for active and 0 for inactive, SUM(is_active)
-- directly counts the active users without needing a CASE statement.

SELECT
    COUNT(*) AS total_users,
    SUM(is_active) AS active_users
FROM users;

-- Insight:
-- The sample contains 91 registered users, and all 91 are active.

-- =====================================================

-- Q2: How many registered users have placed at least one order,
-- and how many have never placed an order?
--
-- Approach:
-- I started from users because I needed to keep every registered user, including
-- users with no orders. That is why I used a LEFT JOIN instead of an INNER JOIN.
-- After the join, I used CASE inside COUNT(DISTINCT ...) to separate users with
-- a matching order_id from users where the order side remained NULL.

SELECT
    COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN u.user_id END) AS users_with_orders,
    COUNT(DISTINCT CASE WHEN o.order_id IS NULL THEN u.user_id END) AS users_without_orders
FROM users u
LEFT JOIN orders o
    ON u.user_id = o.user_id;

-- Insight:
-- 89 users placed at least one order, while 2 registered users never ordered.

-- =====================================================

-- Q3: What is the average number of orders placed per purchasing customer?
--
-- Approach:
-- This requires two levels of aggregation. First, I needed to count orders for
-- each customer. I stored that customer-level result in a CTE so that each row
-- represented one purchasing customer and their order count.
-- Then I averaged those counts in the outer query. Doing AVG(COUNT(...)) directly
-- would not work because the first aggregation has to be completed before the second.

WITH customer_orders AS (
    SELECT
        o.user_id,
        COUNT(o.order_id) AS num_of_orders
    FROM orders o
    GROUP BY o.user_id
)
SELECT
    ROUND(AVG(num_of_orders), 2) AS avg_orders_per_customer
FROM customer_orders;

-- =====================================================

-- Q4: Who are the top 10 customers by total spending from delivered orders?
--
-- Approach:
-- I grouped delivered orders by user_id because total customer spending is the sum
-- of several completed orders, not a value stored on a single row.
-- SUM(grand_total) calculates each customer's completed spend, ORDER BY sorts the
-- customers from highest to lowest, and LIMIT 10 keeps only the highest-value group.
-- I use delivered orders here so cancelled or incomplete orders are not counted as spend.

SELECT
    o.user_id,
    ROUND(SUM(o.grand_total), 2) AS total_spending
FROM orders o
WHERE o.status = 'delivered'
GROUP BY o.user_id
ORDER BY total_spending DESC
LIMIT 10;

-- =====================================================

-- Q5: How many customers are repeat customers, and how many purchased only once?
--
-- Approach:
-- I first needed one row per customer with the number of completed purchases they made,
-- so I counted delivered orders inside a CTE. Once that customer-level result existed,
-- I used conditional COUNT expressions to classify customers with exactly one purchase
-- as one-time customers and customers with more than one purchase as repeat customers.
-- The CTE makes the two-step logic explicit: count per customer first, classify second.

WITH order_amt AS (
    SELECT
        o.user_id,
        COUNT(*) AS num_of_orders
    FROM orders o
    WHERE o.status = 'delivered'
    GROUP BY o.user_id
)
SELECT
    COUNT(CASE WHEN num_of_orders = 1 THEN 1 END) AS one_time_customers,
    COUNT(CASE WHEN num_of_orders > 1 THEN 1 END) AS repeat_customers
FROM order_amt;

-- Insight:
-- Repeat customers make up the overwhelming majority of purchasing customers
-- in this sample, indicating strong repeat purchasing behavior.


-- =====================================================
-- 2. SALES & REVENUE ANALYSIS
-- =====================================================

-- Q6: What is the average total amount spent per customer across all delivered orders?
--
-- Approach:
-- This is different from average order value because the question is about customer
-- lifetime spending within the dataset. I first summed all delivered order values for
-- each customer inside a CTE. That produced one total-spending value per customer.
-- I then averaged those customer totals in the outer query.

WITH total_spending AS (
    SELECT
        o.user_id,
        SUM(o.grand_total) AS total_spending
    FROM orders o
    WHERE o.status = 'delivered'
    GROUP BY o.user_id
)
SELECT
    ROUND(AVG(total_spending), 2) AS avg_spending
FROM total_spending;

-- =====================================================

-- Q7: What is the average order value (AOV) for delivered orders?
--
-- Approach:
-- Here the unit of analysis is one completed order rather than one customer.
-- Because grand_total already represents the final value of each order, I can calculate
-- AOV directly with AVG(grand_total). I filter to delivered orders so the metric reflects
-- completed purchases only.

SELECT
    ROUND(AVG(grand_total), 2) AS avg_order_value
FROM orders
WHERE status = 'delivered';

-- =====================================================

-- Q8: How does revenue change from month to month?
--
-- Approach:
-- I needed to convert individual order timestamps into monthly buckets before revenue
-- could be compared over time. DATE_FORMAT creates a YYYY-MM value for each order,
-- GROUP BY collects all delivered orders from the same month, and SUM(grand_total)
-- calculates the completed revenue generated in each monthly period.

SELECT
    DATE_FORMAT(ordered_at, '%Y-%m') AS order_month,
    SUM(grand_total) AS monthly_revenue
FROM orders
WHERE status = 'delivered'
GROUP BY order_month
ORDER BY order_month;

-- =====================================================

-- Q9: What is the month-over-month revenue growth rate?
--
-- Approach:
-- I could not calculate month-over-month growth directly from raw order rows because
-- I first needed exactly one revenue value per month. The first CTE aggregates delivered
-- revenue by month. Once that monthly table exists, the second CTE uses LAG() to bring
-- the previous month's revenue next to the current month.
-- The final SELECT can then calculate the percentage change between the two values.
-- This is why the query is split into stages: monthly aggregation first, comparison second.

WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(ordered_at, '%Y-%m') AS order_month,
        SUM(grand_total) AS monthly_revenue
    FROM orders
    WHERE status = 'delivered'
    GROUP BY order_month
),
revenue_comparison AS (
    SELECT
        order_month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (ORDER BY order_month) AS previous_month_revenue
    FROM monthly_sales
)
SELECT
    order_month,
    monthly_revenue,
    previous_month_revenue,
    ROUND(
        (monthly_revenue - previous_month_revenue)
        / previous_month_revenue * 100,
        2
    ) AS monthly_growth_pct
FROM revenue_comparison;

-- Data validation / Insight:
-- The dataset runs from 2006-07-04 to 2008-05-06, so July 2006 and May 2008
-- are partial months. Their growth rates should therefore not be interpreted as
-- full-month business performance, especially the sharp drop shown in May 2008.

-- =====================================================

-- Q10: How much delivered revenue comes from discounted orders compared with
-- non-discounted orders?
--
-- Approach:
-- The orders table does not contain a ready-made discounted/non-discounted category,
-- so I created one with CASE based on whether discount_total is greater than zero.
-- I then grouped delivered orders by that derived category and summed grand_total
-- to compare the completed revenue generated by the two groups.

SELECT
    CASE
        WHEN discount_total > 0 THEN 'discounted'
        ELSE 'non-discounted'
    END AS order_type,
    SUM(grand_total) AS total_revenue
FROM orders
WHERE status = 'delivered'
GROUP BY order_type;

-- Insight:
-- Discounted orders generated slightly more total revenue than non-discounted orders.
-- However, revenue alone cannot show whether discounts perform better; the difference
-- could come from more orders, larger orders, or both.


-- =====================================================
-- 3. PRODUCT PERFORMANCE
-- =====================================================

-- Q11: Which 10 products generated the highest revenue from delivered orders?
--
-- Approach:
-- Product names live in products, while actual sold quantities and line-level revenue
-- live in order_items. I therefore followed the relationship path from products to
-- product_variants, then order_items, and finally orders so I could filter to delivered sales.
-- I used SUM(order_items.line_total) because it represents revenue for the specific product
-- line. Using orders.grand_total would incorrectly assign the entire order value to every
-- product contained in that order.

SELECT
    p.name AS product_name,
    SUM(oi.line_total) AS total_revenue
FROM products p
INNER JOIN product_variants pv
    ON p.product_id = pv.product_id
INNER JOIN order_items oi
    ON pv.variant_id = oi.variant_id
INNER JOIN orders o
    ON oi.order_id = o.order_id
WHERE o.status = 'delivered'
GROUP BY p.name
ORDER BY total_revenue DESC
LIMIT 10;

-- =====================================================

-- Q12: Which are the top 3 products by sales quantity within each category?
--
-- Approach:
-- This requires ranking products separately inside every category, so a simple LIMIT 3
-- would not work because LIMIT would return only three rows overall.
-- First, I used a CTE to aggregate units sold for each product within each category.
-- Then I used RANK() with PARTITION BY category_name so the ranking restarts for each
-- category. I placed the ranking in a second CTE because the rank alias does not exist
-- early enough to be filtered in the same SELECT's WHERE clause.
-- The outer query then keeps ranks 1 through 3 from every category.

WITH product_sales AS (
    SELECT
        c.name AS category_name,
        p.name AS product_name,
        SUM(oi.qty) AS units_sold
    FROM products p
    INNER JOIN categories c
        ON p.category_id = c.category_id
    INNER JOIN product_variants pv
        ON p.product_id = pv.product_id
    INNER JOIN order_items oi
        ON pv.variant_id = oi.variant_id
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.status = 'delivered'
    GROUP BY c.name, p.name
),
ranked_products AS (
    SELECT
        category_name,
        product_name,
        units_sold,
        RANK() OVER (
            PARTITION BY category_name
            ORDER BY units_sold DESC
        ) AS rank_in_category
    FROM product_sales
)
SELECT
    category_name,
    product_name,
    units_sold,
    rank_in_category
FROM ranked_products
WHERE rank_in_category <= 3;

-- =====================================================

-- Q13: Which products generated above-average revenue from delivered orders?
--
-- Approach:
-- I first needed to know the total delivered revenue of every product, so I calculated
-- that product-level result inside a CTE. The comparison threshold is the average of
-- those product totals, not the average of individual order lines.
-- I therefore used a scalar subquery on the CTE to calculate the overall product-revenue
-- average, then filtered the product rows whose total_revenue was above that value.

WITH product_revenue AS (
    SELECT
        p.name AS product_name,
        SUM(oi.line_total) AS total_revenue
    FROM products p
    INNER JOIN product_variants pv
        ON p.product_id = pv.product_id
    INNER JOIN order_items oi
        ON pv.variant_id = oi.variant_id
    INNER JOIN orders o
        ON oi.order_id = o.order_id
    WHERE o.status = 'delivered'
    GROUP BY p.name
)
SELECT
    product_name,
    total_revenue
FROM product_revenue
WHERE total_revenue > (
    SELECT AVG(total_revenue)
    FROM product_revenue
);

-- =====================================================

-- Q14: What is the total delivered revenue by category and product,
-- including category subtotals and the overall revenue total?
--
-- Approach:
-- I needed three levels in one result: product revenue, category subtotal, and a grand total.
-- The joins connect categories to delivered product sales, while grouping by category and
-- product creates the detailed product rows. WITH ROLLUP then adds the higher-level subtotal
-- rows automatically. Because ROLLUP represents those summary levels with NULL values,
-- I used COALESCE to replace the NULLs with readable labels.

SELECT
    COALESCE(c.name, 'Grand Total') AS category_name,
    COALESCE(p.name, 'Total') AS product_name,
    SUM(oi.line_total) AS total_revenue
FROM categories c
INNER JOIN products p
    ON c.category_id = p.category_id
INNER JOIN product_variants pv
    ON p.product_id = pv.product_id
INNER JOIN order_items oi
    ON pv.variant_id = oi.variant_id
INNER JOIN orders o
    ON o.order_id = oi.order_id
WHERE o.status = 'delivered'
GROUP BY c.name, p.name WITH ROLLUP;

-- =====================================================

-- Q15: Which products have never been sold in a delivered order?
--
-- Approach:
-- The important part here is preserving products even when no completed sale exists.
-- I therefore started from products and used LEFT JOINs all the way to orders.
-- I placed o.status = 'delivered' inside the JOIN condition rather than the WHERE clause:
-- this means only delivered orders count as a match, while products with no delivered match
-- still remain in the result with NULL on the order side.
-- After grouping by product, HAVING COUNT(o.order_id) = 0 keeps only products that never
-- matched a delivered order.

SELECT
    p.product_id,
    p.name AS product_name,
    COUNT(o.order_id) AS delivered_orders
FROM products p
LEFT JOIN product_variants pv
    ON p.product_id = pv.product_id
LEFT JOIN order_items oi
    ON pv.variant_id = oi.variant_id
LEFT JOIN orders o
    ON oi.order_id = o.order_id
    AND o.status = 'delivered'
GROUP BY p.product_id, p.name
HAVING COUNT(o.order_id) = 0;


-- =====================================================
-- 4. ORDER & OPERATIONAL ANALYSIS
-- =====================================================

-- Q16: What is the average time from order placement to shipment,
-- and from order placement to delivery?
--
-- Approach:
-- The order timestamp and shipping timestamps are stored in different tables, so I joined
-- orders to shipments using order_id. For every order, DATEDIFF calculates the number of
-- days from ordered_at to shipped_at and from ordered_at to delivered_at.
-- Because I only need the overall averages, AVG can be applied directly around DATEDIFF;
-- a CTE would add another step without changing the logic.

SELECT
    ROUND(AVG(DATEDIFF(s.shipped_at, o.ordered_at)), 2) AS avg_days_till_shipped,
    ROUND(AVG(DATEDIFF(s.delivered_at, o.ordered_at)), 2) AS avg_days_till_delivered
FROM orders o
INNER JOIN shipments s
    ON o.order_id = s.order_id;

-- =====================================================

-- Q17: Which orders took the longest time to be delivered?
--
-- Approach:
-- Unlike Q16, this question needs to keep the delivery time of each individual order
-- instead of averaging all orders together. After joining orders to shipments, I calculated
-- days_to_deliver with DATEDIFF for every order, sorted the result from longest to shortest,
-- and used LIMIT 10 to isolate the biggest delivery delays.

SELECT
    o.order_id,
    o.ordered_at AS order_date,
    s.delivered_at AS delivery_date,
    DATEDIFF(s.delivered_at, o.ordered_at) AS days_to_deliver
FROM orders o
INNER JOIN shipments s
    ON o.order_id = s.order_id
ORDER BY days_to_deliver DESC
LIMIT 10;

-- =====================================================

-- Q18: Which shipping carriers have the fastest average delivery time?
--
-- Approach:
-- To compare carriers, I needed the carrier name from carriers, the delivery timestamp
-- from shipments, and the original order timestamp from orders. After joining those tables,
-- I calculated the delivery duration of each order with DATEDIFF.
-- GROUP BY carrier then turns those individual delivery times into one average per carrier,
-- and ascending order puts the fastest carrier first because fewer days means faster delivery.

SELECT
    c.name AS carrier_name,
    ROUND(AVG(DATEDIFF(s.delivered_at, o.ordered_at)), 2) AS avg_days_to_deliver
FROM shipments s
INNER JOIN carriers c
    ON s.carrier_id = c.carrier_id
INNER JOIN orders o
    ON o.order_id = s.order_id
GROUP BY c.name
ORDER BY avg_days_to_deliver ASC;

-- Insight:
-- In the sample results, Shipper ZHISN has the lowest average order-to-delivery time,
-- making it the fastest of the compared carriers.

-- =====================================================

-- Q19: Where do orders spend the most time in the order lifecycle?
--
-- Approach:
-- The status-history table gives me one row for each status change, but it does not directly
-- store how long an order remained in that status. I first needed to place the timestamp of
-- the next status change next to the current one. LEAD() does that, while PARTITION BY order_id
-- keeps each order's timeline separate and ORDER BY changed_at keeps the statuses chronological.
-- I put this logic inside a CTE because the next timestamp had to be created first before I could
-- calculate a duration. In the outer query, TIMESTAMPDIFF converts each status interval to hours,
-- and GROUP BY status averages those intervals so I can compare lifecycle stages.

WITH status_times AS (
    SELECT
        osh.order_id,
        osh.status,
        osh.changed_at,
        LEAD(osh.changed_at) OVER (
            PARTITION BY osh.order_id
            ORDER BY osh.changed_at
        ) AS next_changed_at
    FROM order_status_history osh
)
SELECT
    status,
    ROUND(
        AVG(TIMESTAMPDIFF(HOUR, changed_at, next_changed_at)),
        2
    ) AS avg_hours_in_status
FROM status_times
GROUP BY status
ORDER BY avg_hours_in_status DESC;

-- Insight:
-- The paid stage has the highest average duration at about 203.31 hours,
-- making the payment-to-shipment period the main operational bottleneck in the sample.
-- Delivered and cancelled can return NULL because there may be no following status timestamp.

-- =====================================================

-- Q20: Which customers generated the highest delivered revenue,
-- and how many delivered orders did each of them place?
--
-- Approach:
-- I wanted a customer-value view that combines both frequency and revenue in the same result.
-- I joined users to orders so each customer could be linked to their completed purchases,
-- then filtered to delivered orders. COUNT(order_id) measures how many completed orders each
-- customer placed, while SUM(grand_total) measures the revenue they generated.
-- GROUP BY creates one row per customer and ORDER BY revenue places the highest-value customers first.

SELECT
    u.user_id,
    CONCAT(u.first_name, ' ', u.last_name) AS full_name,
    COUNT(o.order_id) AS num_of_delivered_orders,
    SUM(o.grand_total) AS total_delivered_revenue
FROM users u
INNER JOIN orders o
    ON u.user_id = o.user_id
WHERE o.status = 'delivered'
GROUP BY u.user_id, u.first_name, u.last_name
ORDER BY total_delivered_revenue DESC;

-- Insight:
-- Giorgio Veronesi generated the highest delivered revenue in the sample,
-- while the result also shows that the highest-revenue customer is not necessarily
-- the customer with the highest number of delivered orders.
