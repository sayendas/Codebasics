use gdb023;

#1. Provide the list of markets in which customer "Atliq Exclusive" operates its business in the APAC region.

select distinct market
from dim_customer
where customer='Atliq Exclusive' and region='APAC';

#2. What is the percentage of unique product increase in 2021 vs. 2020? 
#The final output contains these fields, unique_products_2020 unique_products_2021 percentage_chg

with up_2020 as (
select count(distinct fs.product_code) as unique_products_2020
from fact_sales_monthly fs
where fiscal_year=2020),

up_2021 as (
select count(distinct fs.product_code) as unique_products_2021
from fact_sales_monthly fs
where fiscal_year=2021)

select unique_products_2020,unique_products_2021,
round(((unique_products_2021-unique_products_2020)/unique_products_2020)*100,2) as percentage_chg
from up_2020
cross join up_2021;

#3. Provide a report with all the unique product counts for each segment and sort them in descending order of product counts. 
#The final output contains 2 fields, segment product_count

select segment,count(distinct product_code) as product_count
from dim_product
group by segment
order by product_count desc;

#4. Follow-up: Which segment had the most increase in unique products in 2021 vs 2020? 
#The final output contains these fields, segment product_count_2020 product_count_2021 difference

with seg_pro_2020 as (
select segment,count(distinct fs.product_code) as product_count_2020
from dim_product p
inner join fact_sales_monthly fs
on p.product_code=fs.product_code
where fiscal_year=2020
group by segment),

seg_pro_2021 as (
select segment,count(distinct fs.product_code) as product_count_2021
from dim_product p
inner join fact_sales_monthly fs
on p.product_code=fs.product_code
where fiscal_year=2021
group by segment)

select seg_pro_2020.segment,product_count_2020,product_count_2021,
product_count_2021 - product_count_2020 as difference
from seg_pro_2020
inner join seg_pro_2021
on seg_pro_2020.segment=seg_pro_2021.segment
order by difference desc;

#5. Get the products that have the highest and lowest manufacturing costs. 
#The final output should contain these fields, product_code product manufacturing_cost.

select p.product_code, concat(p.product,' ',p.variant) as 'product', manufacturing_cost from 
dim_product p 
inner join
fact_manufacturing_cost fm
on p.product_code=fm.product_code
where fm.manufacturing_cost=(select min(manufacturing_cost) from fact_manufacturing_cost) 
or fm.manufacturing_cost=(select max(manufacturing_cost) from fact_manufacturing_cost);

#6. Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 
#and in the Indian market. The final output contains these fields, customer_code customer average_discount_percentage

select c.customer_code,c.customer,round(avg(pre_invoice_discount_pct)*100,2) as average_discount_percentage
from dim_customer c
inner join fact_pre_invoice_deductions fp
on c.customer_code=fp.customer_code
where fp.fiscal_year=2021 and c.market='India'
group by c.customer_code,c.customer
order by 3 desc
limit 5; 

#7. Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month . 
#This analysis helps to get an idea of low and high-performing months and take strategic decisions. 
#The final report contains these columns: Month Year Gross sales Amount

select monthname(fs.date) 'Month',year(fs.date) 'Year',concat(round(sum(gross_price*sold_quantity)/1000000,2),' ','Millions') 
as 'Gross sales Amount'
from dim_customer c
inner join fact_sales_monthly fs 
on c.customer_code=fs.customer_code
inner join fact_gross_price fg
on fs.product_code=fg.product_code
where c.customer='Atliq Exclusive'
group by year(fs.date),monthname(fs.date);

#8. In which quarter of 2020, got the maximum total_sold_quantity? 
#The final output contains these fields sorted by the total_sold_quantity, Quarter total_sold_quantity

select case when month(date) in (9,10,11) then 1
            when month(date) in (12,1,2) then 2
            when month(date) in (3,4,5) then 3
		    else 4
            end as 'Quarter', 
            sum(sold_quantity) as total_sold_quantity
from fact_sales_monthly
where fiscal_year=2020
group by 
case when month(date) in (9,10,11) then 1
            when month(date) in (12,1,2) then 2
            when month(date) in (3,4,5) then 3
		    else 4
            end
order by 2 desc;


#9. Which channel helped to bring more gross sales in the fiscal year 2021 and 
#the percentage of contribution? The final output contains these fields, channel gross_sales_mln percentage

with channel_sales as (
select channel,concat(round(sum(gross_price*sold_quantity)/1000000,2),' ','Millions') as gross_sales_mln
from dim_customer c
inner join fact_sales_monthly fs 
on c.customer_code=fs.customer_code
inner join fact_gross_price fg
on fs.product_code=fg.product_code
and fs.fiscal_year=fg.fiscal_year
where fs.fiscal_year=2021
group by channel
order by 2 desc),

totalgrosssales as (
select sum(gross_sales_mln) as totsum
from channel_sales)

select channel, gross_sales_mln, round((gross_sales_mln/totsum)*100,2) as percentage
from channel_sales cs
cross join totalgrosssales tgs
order by round((gross_sales_mln/totsum)*100,2) desc;

#10. Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021? 
#The final output contains these fields, division product_code product total_sold_quantity rank_order

create temporary table temp as (
select division,p.product_code,concat(p.product,' ',p.variant) as 'product',
sum(sold_quantity) as total_sold_quantity
from dim_product p
inner join fact_sales_monthly fs
on p.product_code=fs.product_code
where fiscal_year=2021
group by division,p.product_code,concat(p.product,' ',p.variant));

with cte as (
select *,rank() over(partition by division order by total_sold_quantity desc) as rank_order
from temp)

select * from cte where rank_order between 1 and 3;