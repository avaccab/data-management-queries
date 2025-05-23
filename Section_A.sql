/**
	Data Management: Assignment-2
	Barcelona School of Economics, 2024–2025 Academic Year
	Luis Alfredo Gavidia Pantoja and Adrian Alejandro Vacca Bonilla
	November 28, 2024

	SECTION A - EXERCISES
	SQL QUERIES
**/

-- Set the search path to the specific schema for the aviation management database
set search_path to aviation_management_schema;

-- (Q1) Find customers who have made at least one booking in the last month and their booking details
-- Note: Query retrieves customer bookings from the previous month, joining customer and booking tables
-- Filters bookings made within the last month using DATE_TRUNC to get precise monthly boundaries

select c.name, c.customerid, b.*, DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')
from aviation_management_schema.customer c
inner join booking b on c.customerid  = b.customerid
left join flight f on b.flightnumber = f.flightnumber  
WHERE DATE(b.bookingDate) BETWEEN 
    DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month') 
    AND DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 day';

-- (Q2) List all flights with delayed or canceled status
   
-- Includes details about the aircraft and flight crew assigned to these flights
-- Uses string_agg to concatenate crew names and groups by flight and aircraft details
select f.flightnumber, ac.registrationnumber , ac.aircrafttype, string_agg(e."name", ',') as flighcrew
from FLIGHT f
left join aircraftslot s on f.aircraftslotid = s.slotid
left join aircraft ac on s.aircraftid = ac.aircraftid
left join flightcrewassignment f2 on f.flightnumber = f2.flightnumber
left join employee e  on e.employeeid = f2.employeeid 
where f.status in ('Delayed', 'Canceled')
group by 1,2,3
order by f.flightnumber asc;

-- (Q3) Get the total number of miles accumulated by frequent flyers

-- Calculates total accumulated miles for each customer by joining customer and booking tables
-- Frequent flyers are defined as customers with accumulatedmiles > 0

select c.customerid, c.name, sum(c.accumulatedmiles) as accumulatedmiles
from customer c
left join booking b on c.customerid = b.customerid
where c.accumulatedmiles > 0
group by 1, 2
order by c.customerid;

-- (Q4) Find flights departing in the next 7 days that are not fully booked
-- Retrieves flights scheduled within the next week that still have available seats
select f.flightnumber, dep.airportcode ||'-'|| arr.airportcode as route, f.scheduleddeparture 
from flight f
left join airport dep on f.departureairportid = dep.airportid -- join airpot to retrieve departure airport
left join airport arr on f.arrivalairportid = arr.airportid -- join airpot to retrieve arrival airport
where DATE(f.scheduleddeparture) between CURRENT_DATE and DATE(CURRENT_DATE + interval '7 day')
and isFull = false; -- Retrieve only the flights wich are not fully booked

-- (Q5) Generate a report of flights with maintenance schedule conflicts
-- First CTE (Common Table Expression) creates a maintenance event view
-- Identifies flights that overlap with maintenance schedules for the same aircraft
WITH m AS (
    SELECT m.aircraftid, m.starttime, m.duration
    FROM maintenanceevent m
)
select distinct f.scheduleddeparture, f.scheduledarrival, ac.aircraftid, m.starttime, 
    m.startTime + (m.duration || ' hours')::interval as endtime
from flight f
left join aircraftslot s on f.aircraftslotid = s.slotid
left join aircraft ac on s.aircraftid = ac.aircraftid
left join m on m.aircraftid = s.aircraftid
where f.scheduleddeparture between m.starttime and m.startTime + (m.duration || ' hours')::interval
or f.scheduledarrival between m.starttime and m.startTime + (m.duration || ' hours')::interval; -- scheduleddeparture or scheduledarrivel must not be between maintence interval


-- (Q6) Calculate revenue generated by each flight, including payment status

-- Calculate total revenue per flight grouped by payment status using a CTE (Common Table Expression)
-- Renveneu is assumed as the sum of the prices paid to an associated booking

with a as (
    select f.flightnumber, b.paymentstatus, b.price from flight f
    inner join booking b on f.flightnumber  = b.flightnumber 
)
select flightnumber, paymentstatus, sum(price) as revenue
from a
group by flightnumber, paymentstatus
order by flightnumber;

-- (Q7) Find customers who have never booked a flight
-- Uses a LEFT JOIN and checks for NULL bookingid to identify customers with no bookings

select c.customerid, c."name", b.bookingid 
from customer c
left join booking b on c.customerid = b.customerid 
where b.bookingid is null
order by customerid desc;

-- (Q8) Get flights that are fully booked (no available seats)
-- Simple selection of flights marked as full

SELECT f.flightnumber, dep.airportcode ||'-'|| arr.airportcode as route
FROM flight f
left join airport dep on f.departureairportid = dep.airportid -- join airpot to retrieve departure airport
left join airport arr on f.arrivalairportid = arr.airportid -- join airpot to retrieve arrival airport
where f.isfull = true;

-- (Q9) Find frequent flyers with most miles who haven't booked in the past year
-- Calculates accumulated miles for customers who have not made bookings in the previous year

select c.name, sum(c.accumulatedmiles) as miles from customer c
left join booking b on c.customerid = b.customerid
where c.customerid not in 
(
    select b.customerid from booking b
    where EXTRACT(year from date(b.bookingdate)) = EXTRACT(year from CURRENT_DATE) -1
)
group by c.name
order by miles desc;

-- (Q10) Get total bookings and revenue generated per month
-- Calculates total revenue and number of booking by specific month 
select booking_month,  count(*) as numberofbookings, sum(price) as revenue
FROM
(
    select extract(month from DATE(b.bookingdate)) as booking_month, b.price 
    from  booking b 
)
group by booking_month
order by booking_month;

-- (Q11) Get the top 5 most popular flight routes
-- Counts bookings per route and orders by number of bookings in descending order
-- Limit 5 assure a TOP 5 of routes
select  dep.airportcode ||'-'|| arr.airportcode as route, count(b.bookingid) as bookings
from booking b
left join flight f on b.flightnumber  = f.flightnumber
left join airport dep on f.departureairportid = dep.airportid 
left join airport arr on f.arrivalairportid = arr.airportid 
group by 1
order by bookings desc
limit 5;

-- (Q12) Show activity of frequent flyers
-- Summarizes total miles, number of bookings, and total money spent for customers with accumulated miles
-- Frequentflyers are customers who have accumulated more than 0 miles
select c.name, sum(accumulatedmiles) as miles, count(bookingid) as bookings, sum(price) as moneyspent 
from customer c
left join booking b on c.customerid = b.customerid
where c.ACCUMULATEDMILES > 0
group by 1
order by c.name, moneyspent;