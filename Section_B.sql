/**
    Data Management: Assignment-2
    Barcelona School of Economics, 2024–2025 Academic Year
    Luis Alfredo Gavidia Pantoja and Adrian Alejandro Vacca Bonilla
    November 28, 2024

    SECTION B - EXERCISES
    JSON QUERIES
**/

-- (JQ1) Find customers who prefer extra legroom and have submitted low-rated service feedback

-- First, add JSON columns to the CUSTOMER table to store preferences and feedback
alter table CUSTOMER add column customerpreferences jsonb;
alter table CUSTOMER add column customerfeedback jsonb;


-- Insert sample JSON data for customer preferences 
-- This demonstrates a structured JSON with nested preferences for meals, seating, and notifications
update CUSTOMER set customerpreferences = '{ 
    "meal": "vegetarian", 
    "seating": { 
        "aisle": false, 
        "extra_legroom": false, 
        "seat_near_exit": false 
    }, 
    "notifications": { 
        "email": true, 
        "sms": false 
    } 
}'::jsonb
where customerid = 1;

-- Query to find customers with no extra legroom and low service ratings
-- Uses JSON path extraction to filter preferences and feedback
-- Casts service rating to integer for comparison
-- Low service ratings are considered equal or lower than 2
select customer."name", 
       (customerpreferences->'seating'->>'extra_legroom') as extra_legroom, 
       (customerfeedback->'topics'->>'service')::int as service
from customer
where (customerpreferences->'seating'->>'extra_legroom') = 'false'
and (customerfeedback->'topics'->>'service')::int <= 2;

-- (JQ2) Identify flights with maintenance issues in the last 6 months

-- Add a maintenance log column to the FLIGHT table
alter table FLIGHT add column maintencelog jsonb;

-- Update flight with a sample maintenance log 
-- Includes date, check type, and details about specific components
update flight set maintencelog = '{ 
    "date": "2024-10-15", 
    "check_type": "Full Inspection", 
    "components_checked": [ 
        { 
            "name": "Engine", 
            "status": "Operational", 
            "last_replaced": "2023-12-01" 
        }, 
        { 
            "name": "Hydraulics", 
            "status": "Requires Service" 
        } 
    ] 
}'::jsonb;

-- Query to find flights with maintenance events in the last 6 months
-- Converts the date in the maintenance log to a DATE type for comparison
select f.flightnumber, (maintencelog->>'date')::DATE
from flight f
WHERE (maintencelog->>'date')::DATE >= CURRENT_DATE - INTERVAL '6 months';

-- (JQ3) Find customers with specific meal preferences who haven't provided feedback
-- Queries customers with null feedback and a specific meal preference (vegan)
-- In this specif case we retrieve only customers with preference for vegan food.

select c.customerid, c.name,c.email, c.phonenumber, c.customerpreferences 
from CUSTOMER c
where customerfeedback is null
and (customerpreferences->>'meal') ='vegan';

-- (JQ4) Find customer preferences for top-rated flights

-- Retrieves customer preferences for those who gave a perfect 5-star rating
-- Uses a subquery to calculate the average rating across all feedback topics
SELECT 
    customerid, 
    name, 
    customerpreferences->>'meal' AS Meal,
    customerpreferences->'seating'->>'aisle' AS Seating_Aisle,
    customerpreferences->'seating'->>'extra_legroom' AS Seating_Extra_Legroom,
    customerpreferences->'seating'->>'seat_near_exit' AS Seating_Near_Exit,
    -- Calculates average rating across all feedback topics
    (
        SELECT AVG(value::INT)
        FROM jsonb_each(customerfeedback->'topics') AS topic(key, value)
    ) AS total_score
FROM Customer
WHERE (
    SELECT AVG(value::INT)
    FROM jsonb_each(customerfeedback->'topics') AS topic(key, value)
) = 5;

-- This second query analyze most preferred meals for top-rated customers
-- Uses a Common Table Expression (CTE) to first filter top-rated customers
-- Then counts the frequency of meal preferences
-- This same query could be applied to counts the frequency of the values of seating_aisle, seating_extra_legroom and seating_near_exit
WITH preferences_overall AS (
    SELECT 
        customerid, 
        name, 
        customerpreferences->>'meal' AS Meal,
        customerpreferences->'seating'->>'aisle' AS Seating_Aisle,
        customerpreferences->'seating'->>'extra_legroom' AS Seating_Extra_Legroom,
        customerpreferences->'seating'->>'seat_near_exit' AS Seating_Near_Exit,
        -- Calculates average rating across all feedback topics
        (
            SELECT AVG(value::INT)
            FROM jsonb_each(customerfeedback->'topics') AS topic(key, value)
        ) AS total_score
    FROM Customer
    WHERE (
        SELECT AVG(value::INT)
        FROM jsonb_each(customerfeedback->'topics') AS topic(key, value)
    ) = 5
)
-- Count and order meal preferences for top-rated customers
SELECT Meal, COUNT(*) as count_customers
FROM preferences_overall
GROUP BY Meal
ORDER BY count_customers DESC;