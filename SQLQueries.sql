CREATE DATABASE OlistDB;
USE OlistDB;

SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM order_items;
SELECT COUNT(*) FROM order_payments;
SELECT COUNT(*) FROM products;


SELECT top 5 * FROM customers;
SELECT top 5 * FROM orders;
SELECT top 5 * FROM order_items;
SELECT top 5 * FROM order_payments;
SELECT top 5 * FROM products;



-- Does every order have at least one order_item? - operational
select count(*) as 'no_of_orders' from orders left join order_items on orders.order_id = order_items.order_id 
where order_items.order_id is null;

-- Are there orders with multiple payments? - payment
select count(*) as orders_with_multiple_payment from (select orders.order_id,count(*) as 'no_of_payments' from orders 
left join order_payments on orders.order_id = order_payments.order_id 
group by orders.order_id having count(*) > 1) as t;

-- Are there products that never appear in order_items? - product
select * from products left join order_items on order_items.product_id = products.product_id where order_items.product_id IS NULL;






--Q3 Top 10 products by total revenue - product
select top 10 products.product_id,sum(order_items.price + order_items.freight_value) as revenue from order_items join products on order_items.product_id = products.product_id
group by products.product_id order by revenue desc;

-- Q4 Number of orders per customer - customer
select customers.customer_id,count(*) from customers join orders on customers.customer_id = orders.customer_id group by customers.customer_id;


-- ORDER LEVEL

-- Q1: How many distinct orders exist? - Order
SELECT COUNT(DISTINCT order_id) FROM orders;

-- Q2: Total number of orders per order_status - order
select order_status,count(*) from orders group by order_status;

--Q3: Total sales amount - order
select sum(price + freight_value) from order_items;


-- Q4: Order value bucketing (Low / Medium / High) : order
select order_id,sum(price + freight_value) as order_value,
case 
	when sum(price + freight_value) < 100 then 'Low value'
	when sum(price + freight_value) <= 500 then 'Medium Value'
	else 'High Value'
end as value_bucket 
from order_items group by order_id;


-- Q5: Which orders contribute disproportionately to revenue? - order
select order_id,sum(price + freight_value) as order_value
from order_items group by order_id having sum(price + freight_value) > 500;

-- Q: What percentage of total revenue comes from high-value orders? - order
SELECT 
    (high_value_revenue * 100.0 / total_revenue) AS high_value_revenue_percentage
FROM
(
    SELECT 
        SUM(CASE 
                WHEN order_value > 500 THEN order_value 
                ELSE 0 
            END) AS high_value_revenue,
        SUM(order_value) AS total_revenue
    FROM (
        SELECT 
            order_id,
            SUM(price + freight_value) AS order_value
        FROM order_items
        GROUP BY order_id
    ) t
) final;
-- 24% of the company’s total revenue comes from high-value orders (order value > 500).


-- Q: Are there a few extremely high-value orders that distort averages and give a misleading picture of typical order performance? - order
SELECT 
    order_id,
    order_value
FROM (
    SELECT 
        order_id,
        SUM(price + freight_value) AS order_value
    FROM order_items
    GROUP BY order_id
) t
WHERE order_value > 2 * (
    SELECT 
        AVG(order_value)
    FROM (
        SELECT 
            order_id,
            SUM(price + freight_value) AS order_value
        FROM order_items
        GROUP BY order_id
    ) x
)
ORDER BY order_value DESC;
-- Order values are highly skewed, and the business has a long right tail of higher-value orders.



-- PRODUCT-LEVEL SQL

-- Q1 : Which products generate the highest total revenue?
-- Business Problem - Identify the top revenue-driving products so the business knows which 
-- products contribute most to sales.
select 
    top 10 products.product_id,
    sum(order_items.price + order_items.freight_value) as revenue 
from order_items 
    join 
        products on 
        order_items.product_id = products.product_id
    group by products.product_id 
    order by revenue desc;


-- Q2 : Which product categories contribute the most to total revenue?
--Business Problem - Understand which categories drive business revenue to support category-level strategy and planning.
select top 10 products.product_category_name,sum(order_items.price + order_items.freight_value) as revenue 
from order_items join products on order_items.product_id = products.product_id
group by products.product_category_name order by revenue desc;


-- Q3: What percentage of total revenue comes from each product category?
-- Business Problem Measure revenue dependency on categories and identify over- or under-reliance on specific categories.
select products.product_category_name,
sum(order_items.price + order_items.freight_value) * 100 / (select sum(order_items.price + order_items.freight_value) 
from order_items)
as revenue_percentage
from order_items join products on order_items.product_id = products.product_id
group by products.product_category_name having products.product_category_name <> 'NULL' order by revenue_percentage desc;


-- Q4 : Which products have never been sold?
-- Business Problem - Identify dead or inactive inventory that does not contribute to revenue.
select * from products left join order_items on order_items.product_id = products.product_id 
where order_items.product_id IS NULL;


-- Q5: How many products fall into Low / Medium / High revenue buckets?
-- Business Problem: How many products fall into Low / Medium / High revenue buckets?
select f.revenue_bucket,count(*) from
(select case
    when revenue <= 2300 then 'Low'
    when revenue <= 4600 then 'Medium'
    else 'high'
    end as revenue_bucket
from (
select products.product_id,sum(order_items.price + order_items.freight_value) as revenue from order_items join 
products on order_items.product_id = products.product_id
group by products.product_id) t) f
group by f.revenue_bucket;



-- Q6: Is revenue concentrated in a few products or spread across many products?
-- Business Problem: Is revenue concentrated in a few products or spread across many products?
select
(SELECT SUM(revenue)
        FROM (
            SELECT TOP 10
                SUM(oi.price + oi.freight_value) AS revenue
            FROM order_items oi
            GROUP BY oi.product_id
            ORDER BY SUM(oi.price + oi.freight_value) DESC
        ) t
    ) * 100  / (select sum(order_items.price + order_items.freight_value) from order_items)
;


-- Q7: What is the average order value per product category?
-- Business Problem: Understand spending behavior across categories and identify high-value categories.
select product_category_name,avg(order_value) as avg_order from(
select products.product_id,products.product_category_name,
sum(order_items.price + order_items.freight_value) as order_value 
from order_items join products on order_items.product_id = products.product_id
group by products.product_id,products.product_category_name
)t group by product_category_name  having product_category_name <> 'NULL' order by avg_order desc;




-- CUSTOMER-LEVEL SQL

-- Q1 : How many unique customers have placed orders?
-- Business Problem : Measure the active customer base to understand reach and demand.
select count(distinct(customer_id)) from orders;


-- Q2: How many orders does each customer place?
-- Business Problem : Identify repeat vs one-time customers.
select customer_id,count(*) from orders group by customer_id;
select customer_id,count(*) from orders group by customer_id having count(*) > 1;


-- Q3: select customer_id,count(*) from orders group by customer_id having count(*) > 1;
-- Business Problem : Evaluate customer retention strength.
select customer_id,count(*) from orders group by customer_id having count(*) > 1;
-- There are no repeat customers based on customer_id
-- Therefore:
-- Repeat customer percentage = 0%
-- Retention analysis is not applicable at this level


-- Q4 : How much revenue does each customer generate?
-- Business Problems: Identify high-value customers.

select orders.customer_id,sum(order_items.price  + order_items.freight_value) as revenue
from orders join order_items on orders.order_id = order_items.order_id 
group by customer_id
order by revenue desc;

-- Q5 : Which customers contribute disproportionately to revenue?
-- Business Problem : Check if revenue depends heavily on a small customer segment.
select orders.customer_id,sum(order_items.price  + order_items.freight_value) as revenue
from orders join order_items on orders.order_id = order_items.order_id 
group by customer_id having sum(order_items.price  + order_items.freight_value) > 
(select avg(revenue) from 
    (
        select orders.customer_id,sum(order_items.price  + order_items.freight_value) as revenue
from orders join order_items on orders.order_id = order_items.order_id 
group by customer_id) t
)
order by revenue desc;


-- Q6 : What percentage of total revenue comes from top customers?
-- Business Problem : Assess customer-level revenue concentration risk.

select sum(revenue) * 100 / (select sum(order_items.price  + order_items.freight_value) from order_items) from
(
select top 1000 orders.customer_id,sum(order_items.price  + order_items.freight_value) as revenue
from orders join order_items on orders.order_id = order_items.order_id 
group by customer_id
order by revenue desc
) t;





-- PAYMENT-LEVEL SQL

-- Q1 : What are the different payment types used by customers?
-- Business Problem : Identify available and commonly used payment methods to understand customer preferences.
select distinct(payment_type) from order_payments;


-- Q2 : select distinct(payment_type) from order_payments;
-- Business Problem : Understand payment method popularity and customer preference distribution.
select payment_type,count(*) from order_payments group by payment_type;


-- Q3 : What percentage of orders use each payment type?
-- Business Problem: What percentage of orders use each payment type?
select payment_type,count_type * 100.0 / (select count(distinct(order_id)) from order_payments) from (
select payment_type,count(distinct(order_id)) as count_type from order_payments group by payment_type) t;


-- Q4 : What is the average payment value per payment type?
-- Business Problem: Understand whether certain payment methods are associated with higher or lower transaction values.
select payment_type,avg(payment_value) from order_payments group by payment_type;

-- Q5 : How do installments impact payment value?
-- Business Problem: Understand whether higher installment counts are associated with higher payment values, which impacts:Risk,Credit dependency,Payment strategy
select payment_installments,sum(payment_value) from order_payments group by payment_installments;


-- Q6 : select payment_installments,sum(payment_value) from order_payments group by payment_installments;
-- Business Problem : Detect split or complex payments that can affect: Reconciliation,Reporting accuracy,Payment processing complexity
select order_id,count(*) from order_payments group by order_id having count(*) > 1;



-- OPERATIONAL-LEVEL SQL


-- Q1 : How many orders fall under each order status (delivered, canceled, shipped, unavailable, etc.)?
-- Business Problem : The business needs to understand how efficiently orders are being fulfilled and where failures occur (cancellations, unavailability).

select order_status,count(*) as count_status from orders group by order_status;


-- Q2 : What percentage of total orders are canceled or unavailable?
-- Business Problem : High cancellation or unavailable orders indicate operational or supply-chain issues.
select order_status,count_status * 100.0 / (select count(*) from orders) from (
select order_status,count(*) as count_status from orders group by order_status
) t where order_status in ('unavailable','canceled');


-- Q3 : How many orders were never delivered (no delivered timestamp)?
-- Business Problem : Orders that are created but never delivered hurt customer trust and operational reliability.

select count(*) from orders where order_delivered_customer_date is null;



-- Q4 : What is the average delivery time (days) from purchase to delivery?
-- Business Problem : Late deliveries impact customer satisfaction and retention.

select avg(DATEDIFF(day,order_purchase_timestamp,order_delivered_customer_date)) from orders
where order_delivered_customer_date is not null;


-- Q5 : How many orders were delivered after the estimated delivery date?
-- Business Problem : Deliveries later than the estimated date indicate logistics inefficiency.

select count(*) as Count_of_late_orders from orders 
where order_delivered_customer_date > order_estimated_delivery_date;


-- Q6 : For late orders, what is the average delay in days?
-- Business Problem : Knowing how late orders are (not just whether they are late) helps improve logistics planning.

select avg(DATEDIFF(day,order_estimated_delivery_date,order_delivered_customer_date)) as avg_delay_in_late_orders 
from orders where order_delivered_customer_date > order_estimated_delivery_date
and order_delivered_customer_date is not null;



-- Q7 : How long does it take (on average) to ship an order after purchase?
-- Business Problem : Slow processing between order placement and shipping causes delivery delays.
select avg(DATEDIFF(day,order_purchase_timestamp,order_delivered_carrier_date)) from orders
where order_delivered_carrier_date is not null;



-- Q8 : How many orders took more than X days (e.g., 3 days) to ship?
-- Business Problem : Orders stuck too long before shipping indicate warehouse or seller delays.

select count(*) from orders
where DATEDIFF(day,order_purchase_timestamp,order_delivered_carrier_date) > 6
and order_delivered_carrier_date is not null;



-- Q9 : Are there extreme outliers in delivery time?
-- Business Problem : A small number of orders may be extremely delayed, skewing averages.

SELECT 
    order_id,
    delivery_days
FROM (
    SELECT 
        order_id,
        DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date) AS delivery_days
    FROM orders
    WHERE order_delivered_customer_date IS NOT NULL
) t
WHERE delivery_days > (
    SELECT AVG(delivery_days) * 2
    FROM (
        SELECT 
            DATEDIFF(day, order_purchase_timestamp, order_delivered_customer_date) AS delivery_days
        FROM orders
        WHERE order_delivered_customer_date IS NOT NULL
    ) x
)
ORDER BY delivery_days DESC;




-- Q10 : What is the total order cycle time from purchase to delivery?
-- Business Problem : Management wants a single metric to understand total order lifecycle performance.
select avg(DATEDIFF(day,order_purchase_timestamp,order_delivered_customer_date)) from orders
where order_delivered_customer_date is not null;
