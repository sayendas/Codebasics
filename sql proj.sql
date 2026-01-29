#Get all the sales transaction data from fact_sales_monthly table for that customer(croma: 90002002) in the fiscal_year 2021
#and quarter 4

SELECT 
s.date,p.product_code,p.product,
p.variant,s.sold_quantity,g.gross_price,
round(g.gross_price*s.sold_quantity,2) as gross_price_total
FROM fact_sales_monthly s
inner join dim_product p
on s.product_code=p.product_code
inner join fact_gross_price g
on g.product_code=s.product_code and 
   g.fiscal_year=get_fiscal_year(s.date)
WHERE 
	customer_code=90002002 AND
	get_fiscal_year(date)=2021 and
	get_fiscal_quarter(date)="Q4"
ORDER BY date,sold_quantity desc;


#get date wise total gross price for customer(croma: 90002002)

SELECT 
s.date,
round(sum(g.gross_price*s.sold_quantity),2) as gross_price_total
FROM fact_sales_monthly s
inner join dim_product p
on s.product_code=p.product_code
inner join fact_gross_price g
on g.product_code=s.product_code and 
   g.fiscal_year=get_fiscal_year(s.date)
WHERE customer_code=90002002
group by s.date;


#Generate a yearly report for Croma India where there are two columns

#1. Fiscal Year
#2. Total Gross Sales amount In that year from Croma

SELECT 
get_fiscal_year(s.date) as fiscal_year,
round(sum(g.gross_price*s.sold_quantity),2) as gross_price_total
FROM fact_sales_monthly s
inner join dim_product p
on s.product_code=p.product_code
inner join fact_gross_price g
on g.product_code=s.product_code and 
   g.fiscal_year=get_fiscal_year(s.date)
WHERE customer_code=90002002
group by get_fiscal_year(s.date);


#Generate a yearly report for any customer where there are two columns

#1. Fiscal Year
#2. Total Gross Sales amount In that year

call get_monthly_gross_sales_for_customer(90002002);


#Generate a yearly report for any customers where there are two columns

#1. Fiscal Year
#2. Total Gross Sales amount In that year

call get_monthly_gross_sales_for_customers("90002002,90002008");


#Generate a report in which if total quantity of a country in a given year is more than or equal to 5 million, it is gold or silver

set @out_badge = '0';
call gdb0041.get_market_badge('INDIA', 2018, @out_badge);
select @out_badge;


#get net invoice sales customer, market, year, product wise 

select *,
       (1-pre_invoice_discount_pct)*gross_price_total as net_invoice_sales
from sales_preinv_discount;


#get net sales after calculating post invoice sales customer, market, year, product wise 

create view net_sales as
select *,(1-total_post_discount)*net_invoice_sales as net_sales
from sales_postinv_discount;
   
   
#Create a view for gross sales. It should have the following columns,

#date, fiscal_year, customer_code, customer, market, product_code, product, variant,
#sold_quanity, gross_price_per_item, gross_price_total

CREATE 
    ALGORITHM = UNDEFINED 
    DEFINER = root@localhost 
    SQL SECURITY DEFINER
VIEW vw_gross_sales AS
    SELECT 
        s.date AS date,
        s.fiscal_year AS fiscal_year,
        s.customer_code AS customer_code,
        c.customer,
        c.market AS market,
        s.product_code AS product_code,
        p.product AS product,
        p.variant AS variant,
        s.sold_quantity AS sold_quantity,
        g.gross_price AS gross_price_per_item,
        ROUND((s.sold_quantity * g.gross_price),
                2) AS gross_price_total
    FROM
        (((fact_sales_monthly s
        JOIN dim_customer c ON ((s.customer_code = c.customer_code)))
        JOIN dim_product p ON ((s.product_code = p.product_code)))
        JOIN fact_gross_price g ON (((g.fiscal_year = s.fiscal_year)
            AND (g.product_code = s.product_code))));


# get top 5 markets for net sales

select market,
       round(sum(net_sales)/1000000,2) as 'net_sales(in millions)'
from net_sales
where fiscal_year=2021
group by market
order by 'net_sales(in millions)' desc
limit 5;
   
   
# get top 5 customers for net sales

select customer,
       round(sum(net_sales)/1000000,2) as 'net_sales(in millions)'
from net_sales ns
inner join dim_customer c
on ns.customer_code=c.customer_code
where fiscal_year=2021
group by customer
order by 'net_sales(in millions)' desc
limit 5;


#stored procedure to get the top n products by net sales for a given year.

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_top_n_products_by_fiscal_year`(
in_fiscal_year int,
in_top int
)
BEGIN
select product,
       round(sum(net_sales)/1000000,2) as 'net_sales(in millions)'
from net_sales
where fiscal_year=in_fiscal_year
group by product
order by 'net_sales(in millions)' desc
limit in_top
END;

call get_top_n_products_by_fiscal_year(2018,2);






###Supply Chain analytics

#create a table having monthly forecast and monthly sales together
create table fact_act_est as 
(
select 
sm.*,
fm.forecast_quantity
from fact_sales_monthly sm
right join fact_forecast_monthly fm
using (date,product_code,customer_code)
union 
select 
sm.*,
fm.forecast_quantity
from fact_sales_monthly sm
left join fact_forecast_monthly fm
using (date,product_code,customer_code)
);


#insert a record in fact_sales_monthly(as we have created trigger, this will also insert data in fact_act_est)
insert into fact_sales_monthly
(date, product_code, customer_code, sold_quantity)
values('2025-01-27','TEST',1,10);


#insert a record in fact_forecast_monthly(as we have created trigger, this will also update data in fact_act_est)
#reason for update is we specified on duplicate clause
insert into fact_forecast_monthly
(date,fiscal_year, product_code, customer_code, forecast_quantity)
values('2025-01-27',2025,'TEST',1,20);


#calculate net error, absolute net error and pcts and forecast accuracy per customer
with forecast_cte as (
select customer_code,
       sum(sold_quantity) as tot_sold_quantity,
       sum(forecast_quantity) as tot_forecast_quantity,
       sum(forecast_quantity-sold_quantity) as net_error,
       (sum(forecast_quantity-sold_quantity))*100/sum(forecast_quantity) as net_error_pct,
       sum(abs(forecast_quantity-sold_quantity)) as abs_error,
       (sum(abs(forecast_quantity-sold_quantity)))*100/sum(forecast_quantity) as abs_error_pct
from fact_act_est s
where s.fiscal_year=2021
group by customer_code
order by abs_error_pct desc)

select cu.*,
       c.tot_sold_quantity,
       c.tot_forecast_quantity,
       c.net_error,
       c.net_error_pct,
       c.abs_error,
       c.abs_error_pct,
       if(abs_error_pct > 100,0,100-abs_error_pct)
        as forecast_accuracy
 from forecast_cte c
 inner join dim_customer cu
 on c.customer_code=cu.customer_code
 order by forecast_accuracy desc; 
 
 
 #Write a query for the below scenario.

#The supply chain business manager wants to see which customers’ forecast accuracy has dropped from 2020 to 2021. 
#Provide a complete report with these columns: customer_code, customer_name, market, forecast_accuracy_2020, forecast_accuracy_2021

create temporary table forecast_2020_2021 as
select customer_code,
       fiscal_year,
       sum(sold_quantity) as tot_sold_quantity,
       sum(forecast_quantity) as tot_forecast_quantity,
       sum(forecast_quantity-sold_quantity) as net_error,
       (sum(forecast_quantity-sold_quantity))*100/sum(forecast_quantity) as net_error_pct,
       sum(abs(forecast_quantity-sold_quantity)) as abs_error,
       (sum(abs(forecast_quantity-sold_quantity)))*100/sum(forecast_quantity) as abs_error_pct
from fact_act_est s
where s.fiscal_year in (2021,2020)
group by customer_code,fiscal_year
order by abs_error_pct desc;

#take data for fiscal_year 2020
create temporary table forecast_2020 as
select cu.customer_code,
       cu.customer,
       cu.market,
       if(abs_error_pct > 100,0,100-abs_error_pct)
        as forecast_accuracy_2020
 from forecast_2020_2021 c
 inner join dim_customer cu
 on c.customer_code=cu.customer_code and c.fiscal_year=2020
 order by forecast_accuracy_2020 desc;
 
#take data for fiscal_year 2021
create temporary table forecast_2021 as
select cu.customer_code,
       cu.customer,
       cu.market,
       if(abs_error_pct > 100,0,100-abs_error_pct)
        as forecast_accuracy_2021
 from forecast_2020_2021 c
 inner join dim_customer cu
 on c.customer_code=cu.customer_code and c.fiscal_year=2021
 order by forecast_accuracy_2021 desc;
 
 #compare forecast between 2020 and 2021
select *
from forecast_2020 a
inner join forecast_2021 b
using (customer_code,customer,market)
where forecast_accuracy_2021 < forecast_accuracy_2020;


#index creation(ep with and without index)

#-> Filter: (fact_act_est.fiscal_year = 2020)  (cost=145816 rows=142683) (actual time=1186..5730 rows=363523 loops=1)
#    -> Table scan on fact_act_est  (cost=145816 rows=1.43e+6) (actual time=0.0977..5369 rows=1.43e+6 loops=1)
explain analyze
select * from fact_act_est where fiscal_year=2020;


#-> Index lookup on fact_act_est using idx_fiscalyear (fiscal_year=2020)  (cost=80743 rows=713412) (actual time=0.0849..2309 rows=363523 loops=1)
explain analyze
select * from fact_act_est where fiscal_year=2020;

show indexes from fact_act_est;


#composite index
explain 
select * from fact_sales_monthly
where product_code='A0118150101' and customer_code=70002017;