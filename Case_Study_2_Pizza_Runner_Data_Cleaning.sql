/*Data Cleaning*/
/*Table: Runner_orders*/
/*1. Replace blank space with "NULL" in "cancellation" column*/
Update runner_orders
set cancellation = nullif(cancellation, '');

/*2. Replace "null" with "NULL" in "cancellation" column*/
Update runner_orders
set cancellation = NULL
where cancellation = "null";

/*3. Replace "null" with "NULL" in "distance" column */
Update runner_orders
set distance = NULL
where distance = "null"; 

/*4. Extract number from "distance" column*/
Update runner_orders
set distance = REGEXP_SUBSTR(distance,"[0-9]+.[0-9]|[0-9]+");

/*5. Extract number from "duration" column*/
Update runner_orders
set duration = REGEXP_SUBSTR(duration,"[0-9]+.[0-9]|[0-9]+");

/*Table: Customer_orders*/
/*1. Replace blank space with "NULL" in "exclusions" column*/
Update customer_orders
set exclusions = nullif(exclusions, '');

/*2. Replace blank space with "NULL" in "extras" column*/
Update customer_orders
set extras = nullif(extras, '');

/*3. Replace "null" with "NULL" in "exclusions" column*/
Update customer_orders
set exclusions = NULL
where exclusions = "null";

/*4. Replace "null" with "NULL" in "extras" column*/
Update customer_orders
set extras = NULL
where extras = "null";
    