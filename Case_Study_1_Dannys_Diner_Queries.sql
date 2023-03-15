/*1. What is the total amount each customer spent at the restaurant?*/
select customer_id, 
       sum(price) as Amount_spent
from menu m 
join sales s on m.product_id = s.product_id
group by customer_id;


/*2. How many days has each customer visited the restaurant?*/
select customer_id, 
	   count(distinct order_date) as Days_visited
from sales
group by customer_id;


/* 3. What was the first item from the menu purchased by each customer? */
select customer_id, 
       group_concat(distinct product_name) as first_item
from
(select customer_id, 
        product_name, 
        dense_rank() over (partition by customer_id order by order_date) as rank_item
from sales s 
join menu m on s.product_id = m.product_id)a
where rank_item = 1
group by customer_id;


/* 4. What is the most purchased item on the menu and how many times was it purchased by all customers? */
select s.product_id, 
       product_name, 
       count(s.product_id) as times_purchased
from sales s 
join menu m on s.product_id = m.product_id 
group by s.product_id
order by times_purchased desc limit 1;


/*5. Which item was the most popular for each customer?*/
with counting_item as
(select customer_id, 
        product_name, 
        count(product_name) as count_item
from sales s 
join menu m on s.product_id = m.product_id 
group by customer_id, product_name),
ranking_item as 
(select *, dense_rank() over(partition by customer_id order by count_item desc) as rank_item
from counting_item)
select customer_id, 
       group_concat(product_name) as most_popular_item
from ranking_item
where rank_item = 1
group by customer_id;


/* 6. Which item was purchased first by the customer after they 
became a member?*/
with list_item as
(select mem.customer_id, 
        order_date, 
        product_name
from members mem
join sales s on mem.customer_id = s.customer_id
join menu m on s.product_id = m.product_id 
where order_date > join_date),
rank_item as 
(select *, dense_rank() over (partition by customer_id order by order_date) as rank_order
from list_item)
select customer_id, 
       product_name as first_item_purchased
from rank_item
where rank_order = 1;


/* 7. Which item was purchased just before the customer became a member? */
with list_item as
(select mem.customer_id, 
        order_date, 
        product_name
from members mem
join sales s on mem.customer_id = s.customer_id
join menu m on s.product_id = m.product_id 
where order_date < join_date),
rank_item as 
(select *, dense_rank() over (partition by customer_id order by order_date desc) as rank_order
from list_item)
select customer_id, 
       group_concat(product_name) as first_item_purchased
from rank_item
where rank_order = 1
group by customer_id;


/* 8. What is the total items and amount spent for each member 
before they became a member?*/
with item_list as
(select mem.customer_id, 
        order_date, 
        product_name, 
        price
from members mem
join sales s on mem.customer_id = s.customer_id
join menu m on s.product_id = m.product_id 
where order_date < join_date)
select customer_id, 
       count(distinct product_name) as items, 
       sum(price) as amount_spent
from item_list
group by customer_id;


/*9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have? */
with sushi as
(select customer_id, 
        sum(price*20) as points
from sales s 
join menu m on s.product_id = m.product_id
where product_name in ("sushi")
group by customer_id),
other as
(select customer_id, 
        sum(price*10) as points
from sales s 
join menu m on s.product_id = m.product_id
where product_name not in ("sushi")
group by customer_id)
select o.customer_id, 
       coalesce(s.points,0)+coalesce(o.points,0) as points
from sushi s
right join other o on s.customer_id = o.customer_id 
union 
select s.customer_id, 
       coalesce(s.points,0)+coalesce(o.points,0) as points
from sushi s
left join other o on s.customer_id = o.customer_id;


/*10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
not just sushi - how many points do customer A and B have at the end of January?*/
select mem.customer_id, 
       sum(case when order_date<join_date and product_name = "sushi" then price*20
				when order_date<join_date and product_name <> "sushi" then price*10
				when order_date between join_date and date_add(join_date, interval 6 day) then price*20
				when order_date>date_add(join_date,interval 6 day) and product_name = "sushi" then price*20
				when order_date>date_add(join_date,interval 6 day) and product_name<>"sushi" then price*10
			end) as points
from members mem
join sales s on mem.customer_id = s.customer_id
join menu m on s.product_id = m.product_id
where month(order_date)=1
group by mem.customer_id
order by mem.customer_id;


/* BONUS QUESTION - Join All The Things */
select mem.customer_id, 
       order_date, 
       product_name, 
       price, 
       case when order_date>=join_date then "Y"
            when order_date<join_date then "N"
		end as member
from members mem
join sales s on mem.customer_id = s.customer_id
join menu m on s.product_id = m.product_id
union all
select customer_id, 
       order_date, 
       product_name, 
       price, 
       "N" as member
from sales s 
join menu m on s.product_id = m.product_id
where customer_id not in (select customer_id
                          from members)
order by customer_id, order_date;


/*BONUS QUESTION - Rank All The Things*/
with list_item as
(select mem.customer_id, 
        order_date, 
        product_name, 
        price, 
        case when order_date>=join_date then "Y"
             when order_date<join_date then "N"
		end as member
from members mem
join sales s on mem.customer_id = s.customer_id
join menu m on s.product_id = m.product_id
union all
select customer_id, 
       order_date, 
       product_name, 
       price, 
       "N" as member
from sales s 
join menu m on s.product_id = m.product_id
where customer_id not in (select customer_id
                          from members)
order by customer_id, order_date)
select *, "null" as ranking
from list_item
where member = "N"
union all
select *, dense_rank() over (partition by customer_id order by order_date) as ranking
from list_item
where member = "Y"
order by customer_id, order_date;


/*Additional queries to answer:
1. Customer visit pattern
2. Items tried and no. of days customer took to join loyalty program*/

/* 1. On which days each customer visited?*/
select distinct order_date, 
       customer_id, 
       dayname(order_date) as day
from sales
group by customer_id, order_date
order by customer_id;


/*2. Items tried and number of visits made by each customer before joining loyalty program*/
select s.customer_id, 
       group_concat(product_name) as items_tried, 
       count(distinct order_date) as no_of_visits
from sales s 
join members mem on s.customer_id = mem.customer_id
join menu m on s.product_id = m.product_id
where order_date<join_date
group by s.customer_id