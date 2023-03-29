/* A. Pizza Metrics*/
/*1. How many pizzas were ordered?*/
select count(*) as no_of_pizzas_ordered
from customer_orders;

/*2. How many unique customer orders were made?*/
select count(distinct customer_id) as no_of_unique_customer_orders
from customer_orders;

/*3. How many successful orders were delivered by each runner?*/
select runner_id, 
       count(*) as orders_delivered
from runner_orders
where cancellation is NULL
group by runner_id;

/*4. How many of each type of pizza was delivered?*/
select co.pizza_id, 
       pizza_name, count(*)as no_of_pizza_delivered
from runner_orders ro
join customer_orders co on ro.order_id = co.order_id
join pizza_names pn on co.pizza_id=pn.pizza_id
where cancellation is NULL
group by pizza_id;

/*5. How many Vegetarian and Meatlovers were ordered by each customer?*/
select customer_id, 
       pizza_name, 
       count(*) as no_of_pizza_ordered
from customer_orders co 
join pizza_names pn on co.pizza_id = pn.pizza_id
group by customer_id, pizza_name
order by customer_id;

/*6. What was the maximum number of pizza delivered in a single order?*/
select count(*) as maximum_no_of_pizzas_delivered
from customer_orders co
join runner_orders ro on co.order_id = ro.order_id
where cancellation is NULL
group by co.order_id
order by maximum_no_of_pizzas_delivered desc limit 1;

/*7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?*/
With changes_made_or_not as 
(select customer_id, 
        case when exclusions is NULL and extras is NULL then "no change"
			 when exclusions is not NULL and extras is NULL then "at least 1 change"
			 when exclusions is NULL and extras is not NULL then "at least 1 change"
		     when exclusions is not NULL and extras is not NULL then "at least 1 change"
        end as changes_made
from customer_orders
where order_id in (select order_id
                  from runner_orders
                  where cancellation is NULL))
select customer_id, 
       changes_made, 
       count(*) as no_of_delivered_pizzas
from changes_made_or_not
group by customer_id, changes_made
order by customer_id;

/*8. How many pizzas were delivered that had both exclusions and extras?*/
 select count(*) as "no_of_delivered_pizzas_with_both_exclusions_and_extras"
 from customer_orders co
 join runner_orders ro on co.order_id = ro.order_id
 where co.order_id in (select order_id
                       from runner_orders
                       where cancellation is NULL) 
	   and exclusions is not NULL and extras is not NULL;
      
/*9. What was the total volume of pizzas ordered for each hour of the day?*/
select day(order_time) as day, 
       month(order_time) as month, 
       hour(order_time) as hour, 
       count(*) as no_of_pizzas_ordered
from customer_orders
group by order_time, hour(order_time);

/*10. What was the volume of orders for each day of the week?*/
with recursive numbers as
(select 1 as day
union 
select 1+day 
from numbers
where day<7),
day_name as
(select day, case when day = 1 then "Sunday"
                  when day = 2 then "Monday"
                  when day = 3 then "Tuesday"
                  when day = 4 then "Wednesday"
                  when day = 5 then "Thursday"
                  when day = 6 then "Friday"
                  when day = 7 then "Saturday"
			 end as name_week 
from numbers),
day_list as
(select dayname(order_time) as day_of_the_week , 
        count(*) as orders 
from customer_orders
group by dayname(order_time))
select name_week, 
       coalesce(orders, 0) as no_of_orders
from day_name dn
left join day_list dl on dn.name_week = dl.day_of_the_week;



/* B. Runner and Customer Experience*/
/*1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)*/
with recursive weeklist as
(select 1 as N
union all
select 1+N 
from weeklist
where N<5), 
which_week as 
(select runner_id, 
	    case when registration_date between '2021-01-01' and '2021-01-07' then "1"
			 when registration_date between '2021-01-08' and '2021-01-14' then "2"
             when registration_date between '2021-01-15' and '2021-01-21' then "3"
             when registration_date between '2021-01-22' and '2021-01-28' then "4"
             when registration_date between '2021-01-29' and '2021-01-31' then "5"
        end as week
from runners),
count_runner as
(select week, 
        count(*) as registrations
from which_week
group by week)
select N as "Week", 
       coalesce(registrations,0) as No_of_registration
from weeklist wl
left join count_runner cn on wl.N = cn.week;

/*2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
Assumption: when orders are placed, runners are also assigned at the same time*/
with minutes as
(select distinct co.order_id, 
        runner_id, 
        timestampdiff(minute,co.order_time,pickup_time) as minutes_taken_by_runner
from customer_orders co
join runner_orders ro on co.order_id = ro.order_id 
where cancellation is NULL)
select runner_id, 
       avg(minutes_taken_by_runner)as avg_minutes_taken_by_runner
from minutes
group by runner_id;

/*3. Is there any relationship between the number of pizzas and how long the order takes to prepare?*/
select co.order_id, 
       count(pizza_id) as no_of_pizzas, 
       timestampdiff(minute,co.order_time,pickup_time) as preparation_time
from customer_orders co
join runner_orders ro on co.order_id = ro.order_id 
where cancellation is NULL 
group by co.order_id;

/*4. What was the average distance travelled for each customer?*/
with distance as 
(select distinct co.order_id, 
        customer_id, 
        distance
from customer_orders co
join runner_orders ro on co.order_id = ro.order_id
where cancellation is NULL)
select customer_id, 
       avg(distance) as avg_distance_travelled
from distance
group by customer_id;

/*5. What was the difference between the longest and shortest delivery times for all orders?*/
with longest_time as
(select max(duration) as long_time
from runner_orders),
shortest_time as
(select min(duration) as short_time
from runner_orders)
select long_time-short_time as difference_between_longest_and_shortest_duration
from longest_time, shortest_time;

/*6. What was the average speed for each runner for each delivery and do you notice any trend for these values?*/
select runner_id, 
       order_id, 
       distance, 
       duration, 
       avg(distance/duration) as avg_speed
from runner_orders
where cancellation is NULL
group by runner_id, order_id
order by runner_id, order_id;

/*7. What is the successful delivery percentage for each runner?*/
/*Assumption: cancellation is considered as failed delivery*/
with total_delivery as
(select runner_id, 
        count(*) as count_delivery
from runner_orders
group by runner_id),
delivery_success as
(select runner_id, 
        count(*) as count_success
from runner_orders
where cancellation is NULL
group by runner_id)
select td.runner_id, 
       (coalesce(count_success,0)/count_delivery)*100 as successful_delivery_percentage
from total_delivery td
left join delivery_success dc on td.runner_id = dc.runner_id
group by td.runner_id;



/*C. Ingredient Optimisation*/
/*1. What are the standard ingredients for each pizza?*/
with recursive num_digits as
(select 1 as num
union all
select 1+num as num
from num_digits
where num<(select max(char_length(toppings)-char_length(replace(toppings, ',',''))+1) as number_of_ingredients
          from pizza_recipes)
),
toppings_separated as
(select pizza_id, 
        trim(substring_index(substring_index(toppings, ',', num), ',', -1)) as toppings
from num_digits nd
join pizza_recipes pr 
on char_length(toppings)-char_length(replace(toppings, ',',''))+1 >=num
)
select pizza_id, 
       topping_id, 
       topping_name
from toppings_separated ts
join pizza_toppings pt on ts.toppings = pt.topping_id
order by pizza_id, topping_id;

/*2. What was the most commonly added extra?*/
with recursive num_digits as
(select 1 as num
union all
select 1+num as num
from num_digits
where num<(select max(char_length(extras)-char_length(replace(extras, ',',''))+1) as number_of_ingredients
          from customer_orders)
),
toppings_separated as
(select trim(substring_index(substring_index(extras, ',', num), ',', -1)) as extras
from num_digits nd
join customer_orders co 
on char_length(extras)-char_length(replace(extras, ',',''))+1 >=num
)
select extras as topping_id, 
       topping_name
from
(select extras, 
        count(*) as count_extras, 
        topping_name
from toppings_separated ts
join pizza_toppings pt on ts.extras = pt.topping_id
group by extras) a
order by count_extras desc limit 1;

/*3. What was the most common exclusion?*/
with recursive num_digits as
(select 1 as num
union all
select 1+num as num
from num_digits
where num<(select max(char_length(exclusions)-char_length(replace(exclusions, ',',''))+1) as number_of_ingredients
          from customer_orders)
),
toppings_separated as
(select trim(substring_index(substring_index(exclusions, ',', num), ',', -1)) as exclusions
from num_digits nd
join customer_orders co 
on char_length(exclusions)-char_length(replace(exclusions, ',',''))+1 >=num
)
select exclusions as topping_id, 
       topping_name
from
(select exclusions, 
        count(*) as count_exclusions, 
        topping_name
from toppings_separated ts
join pizza_toppings pt on ts.exclusions = pt.topping_id
group by exclusions) a
order by count_exclusions desc limit 1;

/*4. Generate an order item for each record in the customers_orders table in the format of one of the following:
Meat Lovers
Meat Lovers - Exclude Beef
Meat Lovers - Extra Bacon
Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers*/
with recursive num_digits as
(select 1 as num
union all
select 1+num as num
from num_digits
where num<(select max(number_of_ingredients) as max_ingredient
           from 
            (select max(char_length(exclusions)-char_length(replace(exclusions, ',',''))+1) as number_of_ingredients
             from customer_orders
             union all
             select max(char_length(extras)-char_length(replace(extras, ',',''))+1) as number_of_ingredients
             from customer_orders) a )
),
orders as
(select *, row_number() over (order by order_id) as rownum
from customer_orders),
toppings_exclusions as
(select order_id, 
        pizza_id, 
        rownum, 
        trim(substring_index(substring_index(exclusions, ',', num), ',', -1)) as exclusions
from num_digits nd
join orders o 
on char_length(exclusions)-char_length(replace(exclusions, ',',''))+1 >=num),
toppings_extras as
(select order_id, 
        pizza_id, 
        rownum, 
        trim(substring_index(substring_index(extras, ',', num), ',', -1)) as extras
from num_digits nd
join orders o 
on char_length(extras)-char_length(replace(extras, ',',''))+1 >=num),
exclusions_with_toppings as
(select order_id, 
        texclu.pizza_id, 
        rownum, 
        pizza_name, 
        group_concat(topping_name) as toppings
from toppings_exclusions texclu
join pizza_toppings pt on texclu.exclusions = pt.topping_id
join pizza_names pn on texclu.pizza_id = pn.pizza_id
group by order_id, texclu.pizza_id, rownum),
extras_with_toppings as
(select order_id, 
        textr.pizza_id, 
        rownum, 
        pizza_name, 
        group_concat(topping_name) as toppings
from toppings_extras textr
join pizza_toppings pt on textr.extras = pt.topping_id
join pizza_names pn on textr.pizza_id = pn.pizza_id
group by order_id, textr.pizza_id, rownum),
joined_list as
(select cwt.order_id, 
        concat(cwt.pizza_name, " - Exclude ", cwt.toppings, " - Extras ", rwt.toppings) as order_item
from exclusions_with_toppings cwt
join extras_with_toppings rwt on cwt.order_id = rwt.order_id and cwt.pizza_id=rwt.pizza_id and cwt.rownum = rwt.rownum
union all
select cwt.order_id, 
       concat(cwt.pizza_name, " - Exclude ", cwt.toppings) as order_item
from exclusions_with_toppings cwt
left join extras_with_toppings rwt on cwt.order_id = rwt.order_id and cwt.pizza_id=rwt.pizza_id and cwt.rownum = rwt.rownum
where rwt.order_id is null
union all
select rwt.order_id, 
       concat(rwt.pizza_name, " - Extras ", rwt.toppings) as order_item
from extras_with_toppings rwt
left join exclusions_with_toppings cwt on cwt.order_id = rwt.order_id and cwt.pizza_id=rwt.pizza_id and cwt.rownum = rwt.rownum
where cwt.order_id is null
union all
select order_id, 
       pizza_name as order_item
from customer_orders co
join pizza_names pn on co.pizza_id = pn.pizza_id
where exclusions is NULL and extras is NULL
) 
select *
from joined_list
order by order_id;

/*5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders 
table and add a 2x in front of any relevant ingredients. For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"*/
with recursive num_digits as
(select 1 as num
union all
select 1+num as num
from num_digits
where num<(select max(char_length(toppings)-char_length(replace(toppings, ',',''))+1) as number_of_ingredients
          from pizza_recipes)
),
orders_with_toppings as
(select order_id, 
        co.pizza_id, 
        toppings, 
        exclusions, 
        extras, 
        row_number() over (order by order_id) as rownum
from customer_orders co
join pizza_recipes pr on co.pizza_id = pr.pizza_id),
toppings_separated as
(select order_id, 
        pizza_id, 
        rownum, 
        trim(substring_index(substring_index(toppings, ',', num), ',', -1)) as toppings_sep
from num_digits nd
join orders_with_toppings owt
on char_length(toppings)-char_length(replace(toppings, ',',''))+1 >=num),
exclusions_separated as
(select order_id, 
        pizza_id, 
        rownum, 
        trim(substring_index(substring_index(exclusions, ',', num), ',', -1)) as exclusions_sep
from num_digits nd
join orders_with_toppings owt 
on char_length(exclusions)-char_length(replace(exclusions, ',',''))+1 >=num
where exclusions is not Null),
toppings_with_exclusions as
(select ts.order_id, 
        ts.pizza_id, 
        ts.rownum, 
        toppings_sep
from toppings_separated ts
left join exclusions_separated es on ts.order_id=es.order_id and ts.pizza_id = es.pizza_id and ts.toppings_sep = es.exclusions_sep 
                                                             and ts.rownum = es.rownum
where exclusions_sep is NULL),
extras_separated as
(select order_id, 
        pizza_id, 
        rownum, 
        trim(substring_index(substring_index(extras, ',', num), ',', -1)) as extras_sep
from num_digits nd
join orders_with_toppings owt 
on char_length(extras)-char_length(replace(extras, ',',''))+1 >=num
where extras is not NULL),
toppings_with_extras as
(select twe.order_id, 
        twe.pizza_id, 
        twe.rownum,
        toppings_sep,
        extras_sep
from toppings_with_exclusions twe
left join extras_separated es on twe.order_id=es.order_id and twe.pizza_id = es.pizza_id and twe.toppings_sep = es.extras_sep 
                                                          and twe.rownum = es.rownum),
topping_names as
(select order_id, 
        pizza_id, 
        rownum, 
        extras_sep, 
        topping_name, 
        row_number() over (order by order_id, pizza_id, topping_name)
from toppings_with_extras twe
join pizza_toppings pt on twe.toppings_sep = pt.topping_id),
toppings_grouped as
(select order_id, 
		pizza_id, 
        group_concat(case when extras_sep is Null then topping_name
						  when extras_sep is not Null then concat("2X", topping_name)
					end) as toppings
from topping_names
group by order_id, pizza_id, rownum)
select order_id, 
       tg.pizza_id, 
       concat(pizza_name, ": ", toppings) as ingredient_list 
from toppings_grouped tg
join pizza_names pn on tg.pizza_id=pn.pizza_id
order by order_id, tg.pizza_id;

/* 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?*/
with recursive num_digits as
(select 1 as num
union all
select 1+num as num
from num_digits
where num<(select max(char_length(toppings)-char_length(replace(toppings, ',',''))+1) as number_of_ingredients
          from pizza_recipes)
),
orders_with_toppings as
(select co.order_id, 
        co.pizza_id, 
        toppings, 
        exclusions, 
        extras, 
        row_number() over (order by order_id) as rownum
from customer_orders co
join pizza_recipes pr on co.pizza_id = pr.pizza_id
left join runner_orders ro on co.order_id = ro.order_id
where cancellation is null),
toppings_separated as
(select order_id, 
		pizza_id, 
        rownum, 
        trim(substring_index(substring_index(toppings, ',', num), ',', -1)) as toppings_sep
from num_digits nd
join orders_with_toppings owt
on char_length(toppings)-char_length(replace(toppings, ',',''))+1 >=num),
exclusions_separated as
(select order_id, 
        pizza_id, 
        rownum, 
		trim(substring_index(substring_index(exclusions, ',', num), ',', -1)) as exclusions_sep
from num_digits nd
join orders_with_toppings owt 
on char_length(exclusions)-char_length(replace(exclusions, ',',''))+1 >=num
where exclusions is not Null),
toppings_with_exclusions as
(select ts.order_id, 
        ts.pizza_id, 
        ts.rownum, 
        toppings_sep
from toppings_separated ts
left join exclusions_separated es on ts.order_id=es.order_id and ts.pizza_id = es.pizza_id and ts.toppings_sep = es.exclusions_sep 
                                                             and ts.rownum = es.rownum
where exclusions_sep is NULL),
extras_separated as
(select order_id, 
        pizza_id, 
        rownum, 
        trim(substring_index(substring_index(extras, ',', num), ',', -1)) as extras_sep
from num_digits nd
join orders_with_toppings owt 
on char_length(extras)-char_length(replace(extras, ',',''))+1 >=num
where extras is not NULL),
toppings_with_extras as
(select toppings_sep
from toppings_with_exclusions twe
union all
select extras_sep 
from extras_separated es
),
topping_names as
(select toppings_sep, 
        topping_name
from toppings_with_extras twe
join pizza_toppings pt on twe.toppings_sep = pt.topping_id)
select topping_name, 
	   count(topping_name) as times_used
from topping_names
group by topping_name
order by times_used desc;
 
 
 
/*D. Pricing and Ratings*/
/*1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has 
Pizza Runner made so far if there are no delivery fees?*/
with meat as
(select count(*)*12 as meat_cost
from customer_orders co
join pizza_names pn on co.pizza_id=pn.pizza_id
join runner_orders ro on co.order_id = ro.order_id
where pizza_name = "Meatlovers" and cancellation is NULL),
vegetarian as
(select count(*)*10 as veg_cost
from customer_orders co
join pizza_names pn on co.pizza_id=pn.pizza_id
join runner_orders ro on co.order_id = ro.order_id
where pizza_name = "Vegetarian" and cancellation is NULL)
select meat_cost+veg_cost as money_made_so_far
from meat, vegetarian;

/*2. What if there was an additional $1 charge for any pizza extras? Add cheese is $1 extra*/
with meat as
(select count(*)*12 as meat_cost
from customer_orders co
join pizza_names pn on co.pizza_id=pn.pizza_id
join runner_orders ro on co.order_id = ro.order_id
where pizza_name = "Meatlovers" and cancellation is NULL),
vegetarian as
(select count(*)*10 as veg_cost
from customer_orders co
join pizza_names pn on co.pizza_id=pn.pizza_id
join runner_orders ro on co.order_id = ro.order_id
where pizza_name = "Vegetarian" and cancellation is NULL),
extras as 
(select sum(char_length(extras)-char_length(replace(extras,',',''))+1) as extras_cost 
from customer_orders 
where extras is not NULL)
select meat_cost+veg_cost+extras_cost as money_made_so_far
from meat, vegetarian, extras;

/*3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would 
you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each 
successful customer order between 1 to 5.*/
Drop table if exists runner_ratings;
create table runner_ratings (
order_id integer,
customer_id integer,
runner_id integer,
rating integer);

insert into runner_ratings
  (order_id , customer_id, runner_id, rating)
values
  ('1', '101', '1', '3'),
  ('2', '101', '1', '4'),
  ('3', '102', '1', '4'),
  ('4', '103', '2', '5'),
  ('5', '104', '3', '4'),
  ('7', '105', '2', '3'),
  ('8', '102', '2', '4'),
  ('10', '104', '1', '3');
  
/*4. Using your newly generated table - can you join all of the information together to form a table which has the 
following information for successful deliveries?
customer_id
order_id
runner_id
rating
order_time
pickup_time
Time between order and pickup
Delivery duration
Average speed
Total number of pizzas */
select rr.customer_id,
       rr.order_id,
       rr.runner_id,
       rating,
       order_time,
       pickup_time,
       timestampdiff(minute, order_time, pickup_time) as Time_between_order_and_pickup,
       duration as Delivery_duration,
       (distance/duration) as Average_speed,
       count(*) as Total_number_of_pizzas
from customer_orders co
join runner_ratings rr on co.order_id = rr.order_id
join runner_orders ro on ro.order_id = co.order_id
group by rr.customer_id, rr.order_id, rr.runner_id
order by rr.customer_id, rr.order_id;

/*5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 
per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?*/
with meat as
(select count(*)*12 as meat_cost
from customer_orders co
join pizza_names pn on co.pizza_id=pn.pizza_id
join runner_orders ro on co.order_id = ro.order_id
where pizza_name = "Meatlovers" and cancellation is NULL),
vegetarian as
(select count(*)*10 as veg_cost
from customer_orders co
join pizza_names pn on co.pizza_id=pn.pizza_id
join runner_orders ro on co.order_id = ro.order_id
where pizza_name = "Vegetarian" and cancellation is NULL),
distance_travelled_payout as
(select sum(distance)*0.3 as runner_payout 
from runner_orders ro
where cancellation is NULL)
select meat_cost+veg_cost-runner_payout as money_made_so_far
from meat, vegetarian, distance_travelled_payout;



/*E. Bonus Questions*/
/*If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to 
demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?*/
insert into pizza_names (pizza_id, pizza_name)
values (3, 'Supreme');
insert into pizza_recipes (pizza_id, toppings)
values (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');