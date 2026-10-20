create table amazon_sales (
    order_id varchar(20),
    order_date date,
    customer_id varchar(20),
    customer_name varchar(100),
    product_id varchar(20),
    product_name varchar(150),
    category varchar(50),
    brand varchar(50),
    quantity int,
    unit_price numeric(10,2),
    discount numeric(5,2),
    tax numeric(10,2),
    shipping_cost numeric(10,2),
    total_amount numeric(12,2),
    payment_method varchar(50),
    order_status varchar(30),
    city varchar(50),
    state varchar(50),
    country varchar(50),
    seller_id varchar(20)
);

select * from amazon_sales
limit 10;


-- 1. How many orders were placed?

select count(distinct order_id) as order_count
from amazon_sales;

-- 2. What is the average order value?

select round(avg(total_amount), 2) as avg_order_value from amazon_sales;

-- 3. How many units were sold in total?

select sum(quantity) as total_units_sold from amazon_sales;

-- 4. Top 10 Products by Quantity Sold.

select product_id, product_name, sum(quantity) as quantity_sold
from amazon_sales
group by product_id, product_name
order by quantity_sold desc
limit 10;

-- 5. Which categories contribute the most to total revenue?

with category_sales as (
	select
		category, sum(total_amount) as total_revenue
	from amazon_sales
group by category
	)
select category, total_revenue,
	round(total_revenue * 100 / sum(total_revenue) over(), 2) as pct_of_contrib
from category_sales;

-- 6. Which categories have the highest average order value (AOV)?

select category, count(distinct order_id) as order_count,
	round(avg(total_amount), 2) as aov_of_catg
	from amazon_sales
group by category
order by aov_of_catg desc;

-- 7. Which categories generate the most revenue relative to the quantity sold?

select category, sum(total_amount) as total_revenue, sum(quantity) as sold_qty
from amazon_sales
group by category
order by total_revenue desc, sold_qty asc;

-- 8. Which payment methods generate the highest revenue, and what is the average amount spent per order for each method?

with payment_revenue as (
    select
        payment_method,
        sum(total_amount) as revenue_generated
    from amazon_sales
    group by payment_method
),
payment_orders as (
    select
        payment_method,
        count(order_id) as order_count
    from amazon_sales
    group by payment_method
)
select
    r.payment_method,
    r.revenue_generated,
    o.order_count,
    round(r.revenue_generated / o.order_count, 2) as aov
from payment_revenue as r
left join payment_orders as o
    on r.payment_method = o.payment_method
order by r.revenue_generated desc;

-- 9. Find the highest-selling product (by quantity sold) within every category.

with quantity_sales as(
	select category, product_id, product_name, sum(quantity) as quantity_sold
	from amazon_sales
	group by category, product_id, product_name
	),
ranked_products as(
	select row_number() over(partition by category order by quantity_sold desc) as sales_rank,
	product_id, product_name, category, quantity_sold
	from quantity_sales
	)
select * from ranked_products
where sales_rank = 1;

-- 10. Identify customers who placed more than one order. Show their total number of orders and total spending.

select customer_id, customer_name, count(distinct order_id) as total_orders,
sum(total_amount) as total_spending from amazon_sales
group by customer_id, customer_name
having count(distinct order_id)>1;

-- 11. Find the Top 3 products (by quantity sold) within every category.

with quantity_sales as (
	select product_id, product_name, sum(quantity) as quantity_sold, category
	from amazon_sales
	group by product_id, product_name, category
	),
ranked_products as(
	select row_number() over(partition by category order by quantity_sold desc) as sales_rank,
	product_id, product_name, category, quantity_sold
	from quantity_sales
	)
select * from ranked_products
where sales_rank in (1,2,3);

-- 12. Calculate the running (cumulative) revenue by order date.

with current_revenue as(
	select order_date, sum(total_amount)
		as daily_revenue from amazon_sales
	group by order_date
	)
select *, (sum(daily_revenue) over(order by order_date))
	as running_revenue from current_revenue;

-- 13. Find customers whose total spending exceeds the average customer spending.

with customer_spending as (
    select
        customer_id, customer_name,
        sum(total_amount) as total_spending
    from amazon_sales
    group by customer_id, customer_name
),
average_customer_spending as (
    select avg(total_spending) as avg_spending
    from customer_spending
)
select
    c.customer_id, c.customer_name, c.total_spending,
    round(a.avg_spending, 2) as avg_spending
from customer_spending c
cross join average_customer_spending a
where c.total_spending > a.avg_spending
order by c.customer_id asc;

-- 14. Find the highest-selling product in every city.

with sales as (
	select city, product_id, product_name, sum(quantity) as quantity_sold,
	row_number() over (partition by city order by sum(quantity) desc) as rn
	from amazon_sales
	group by city, product_id, product_name
	)
select * from sales
where rn = 1;

-- 15. Find the Top 5 customers based on total spending and calculate their percentage contribution to overall revenue.

select customer_id, customer_name, sum(total_amount) as total_spending,
round(sum(total_amount) * 100.0 / sum(sum(total_amount)) over (), 2) as percentage_contribution
from amazon_sales
group by customer_id, customer_name
order by total_spending desc
limit 5;

-- 16. Find products purchased by the largest number of distinct customers.

select product_id, product_name, count(distinct(customer_id)) as customer_count
from amazon_sales
group by product_id, product_name
order by customer_count desc
limit 1;

-- 17. Which sellers generate the highest revenue, and how many units do they sell?

select seller_id, sum(total_amount) as revenue,
sum(quantity) as quantity_sold
from amazon_sales
group by seller_id
order by revenue desc;

-- 18. Identify each customer's biggest purchase.

with customer_table as(
    select
        customer_id, customer_name, order_id,
        sum(total_amount) as highest_order,
        row_number() over (
            partition by customer_id, customer_name
            order by sum(total_amount) desc
        ) as sales_rank
    from amazon_sales
    group by customer_id, customer_name, order_id
)
select *
from customer_table
where sales_rank = 1;

-- 19. Find customers who purchased in at least two consecutive months.

with customer_months as(
	select distinct customer_id, customer_name,
	date_trunc('month', order_date)::date as month
	from amazon_sales
	order by month
	),
monthly_history as (
	select customer_id, customer_name, month,
	lag(month) over (partition by customer_id,
	customer_name order by month) as previous_month
	from customer_months
)
select customer_id, customer_name, month,
previous_month from monthly_history
where previous_month is not null
and month = (previous_month + interval '1 month')::date;

/*
20. Classify each order as either Weekday or Weekend. 
Then calculate Total Revenue, Total Orders, and Average Order Value (AOV) separately for each group.
*/

select sum(total_amount) as total_revenue, count(order_id) as order_count,
	round(avg(total_amount), 2) as aov,
	case 
        when extract(isodow from order_date) in (6, 7) then 'Weekend'
        else 'Weekday'
    end as day_type
	from amazon_sales
group by day_type;

/*
  21. Calculate monthly revenue and show:

* Current month revenue
* Previous month revenue
* MoM growth %
* Handle the first month appropriately

*/

with monthly_rev as(
	select date_trunc('month', order_date)::date as month,
	sum(total_amount) as total_revenue
	from amazon_sales
	group by month
	),
previous_rev as(
	select *, lag(total_revenue) over(order by month) as previous_revenue
	from monthly_rev
)
select month, total_revenue, previous_revenue,
round((100.0 * (total_revenue - previous_revenue) / previous_revenue), 2)
	as mom_growth_pct
from previous_rev
order by month;

-- Q22. Which customers placed their second recorded order within 30 days of their first recorded order?

with ranked_orders as (
    select
        customer_id, customer_name, order_id, order_date,
        row_number() over (
            partition by customer_id, customer_name
            order by order_date, order_id
        ) as order_rank,
        lag(order_date) over (
            partition by customer_id, customer_name
            order by order_date, order_id
        ) as previous_order_date
    from amazon_sales
)
select
    customer_id, customer_name,
	previous_order_date as first_order_date,
    order_date as second_order_date,
    order_date - previous_order_date as days_between_orders
from ranked_orders
where order_rank = 2
  and order_date <= previous_order_date + interval '30 days'
order by days_between_orders;

/*
Q23 — Find customers whose total spending is greater than the average total spending of customers in their city.

Return:

customer_id
customer_name
city
total_spending
city_average_spending
*/

with customer_spending as (
    select
        customer_id, customer_name, city,
        sum(total_amount) as total_spending
    from amazon_sales
    group by customer_id, customer_name, city
),
city_averages as (
    select
        city,
        round(avg(total_spending), 2) as city_average_spending
    from customer_spending
    group by city
)
select
    cs.customer_id,
    cs.customer_name,
    ca.city,
    cs.total_spending,
    ca.city_average_spending
from customer_spending cs
left join city_averages ca
    on cs.city = ca.city
where cs.total_spending > ca.city_average_spending
order by cs.customer_id;

/*
Q24 — Identify the top 10% of customers by total spending and determine what percentage of the company's total revenue they generate.

Return:

customer_id
customer_name
total_spending
customer_rank
revenue_contribution_pct
*/
with customer_totals as (
    select
        customer_id,
        customer_name,
        sum(total_amount) as total_spending,
        row_number() over (
            order by sum(total_amount) desc
        ) as customer_rank
    from amazon_sales
    group by customer_id, customer_name
),
top_customers as (
    select *
    from customer_totals
    where customer_rank <= (
        select ceil(count(*) * 0.10)
        from customer_totals
    )
)
select
    customer_id,
    customer_name,
    total_spending,
    customer_rank,
    round(
        sum(total_spending) over () * 100.0 /
        (select sum(total_amount) from amazon_sales),
        2
    ) as revenue_contribution_pct
from top_customers
order by customer_rank;

-- Q25 — Which calendar month generated the highest returning-customer revenue, based on the customer's first valid purchase month recorded in the dataset?

with first_purchases as (
    select
        customer_id,
        customer_name,
        min(order_date) as first_purchase_date
    from amazon_sales
    where order_status in ('Delivered', 'Shipped')
    group by customer_id, customer_name
),
valid_orders as (
    select
        customer_id,
        customer_name,
        order_date,
        total_amount
    from amazon_sales
    where order_status in ('Delivered', 'Shipped')
),
customer_types as (
    select
        fp.customer_id,
        fp.customer_name,
        vo.order_date,
        fp.first_purchase_date,
        vo.total_amount,
        case
            when date_trunc('month', vo.order_date)::date >
                 date_trunc('month', fp.first_purchase_date)::date
            then 'Returning'
            else 'New'
        end as customer_type
    from first_purchases fp
    join valid_orders vo
        on fp.customer_id = vo.customer_id
       and fp.customer_name = vo.customer_name
),
monthly_revenue as (
    select
        date_trunc('month', order_date)::date as month,
        sum(case
            when customer_type = 'New' then total_amount
            else 0
        end) as new_revenue,
        sum(case
            when customer_type = 'Returning' then total_amount
            else 0
        end) as returning_revenue,
        sum(total_amount) as total_revenue
    from customer_types
    group by month
),
ranked_months as (
    select
        *,
        dense_rank() over (
            order by returning_revenue desc
        ) as revenue_rank
    from monthly_revenue
)
select
    month,
    new_revenue,
    returning_revenue,
    total_revenue
from ranked_months
where revenue_rank = 1
order by month;


-- POWER BI ONLY: Monthly New vs Returning Customer Revenue
-- This is a separate query. For presentation purpose only.

with first_purchases as (
    select customer_id, customer_name,
		min(order_date) as first_purchase_date
    from amazon_sales
    where order_status in ('Delivered', 'Shipped')
    group by customer_id, customer_name
),
valid_orders as (
    select
        customer_id, customer_name,
			order_date, total_amount
    from amazon_sales
    where order_status in ('Delivered', 'Shipped')
),
customer_types as (
    select vo.order_date, vo.total_amount,
		case
            when date_trunc('month', vo.order_date)::date >
                 date_trunc('month', fp.first_purchase_date)::date
            then 'Returning'
            else 'New'
        end as customer_type
    from valid_orders vo
    join first_purchases fp
        on vo.customer_id = fp.customer_id
       and vo.customer_name = fp.customer_name
),
monthly_revenue as (
    select date_trunc('month', order_date)::date as month,
        sum(
            case
                when customer_type = 'New'
                then total_amount
                else 0
            end
        ) as new_revenue,
        sum(
            case
                when customer_type = 'Returning'
                then total_amount
                else 0
            end
        ) as returning_revenue,
        sum(total_amount) as total_revenue
    from customer_types
    group by date_trunc('month', order_date)::date
)
select month, new_revenue,
	returning_revenue, total_revenue
from monthly_revenue
order by month;