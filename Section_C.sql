/**
    Data Management: Assignment-2
    Barcelona School of Economics, 2024–2025 Academic Year
    Luis Alfredo Gavidia Pantoja and Adrian Alejandro Vacca Bonilla
    November 28, 2024

    SECTION C - EXERCISES
    TRIGGERS
**/

/*(T1) Aircraft Maintenance Schedule Check Trigger
    Purpose: Prevent aircraft from being assigned to flights during scheduled maintenance
    
    Key Functionality:
    - Checks if an aircraft is scheduled for maintenance during a proposed flight time
    - Raises an exception if maintenance conflicts with flight scheduling
    - Ensures aircraft maintenance integrity and operational safety
*/

-- Create a function to check maintenance schedule before flight assignment
create or replace function check_maintence_schedule()
returns trigger as $$
DECLARE
    maintenance_count INTEGER;  -- Tracks number of maintenance conflicts
    aircraft_id INTEGER;         -- Stores the aircraft ID
begin 
    -- Retrieve the aircraft ID from the aircraft slot
    select aircraftid into aircraft_id
    from aircraftslot
    where slotid = new.aircraftslotid;

    -- Check for maintenance events that overlap with the proposed flight time
    SELECT COUNT(*) INTO maintenance_count
    FROM aviation_management_schema.MaintenanceEvent me
    JOIN aviation_management_schema.AircraftSlot ms ON me.aircraftSlotID = ms.slotID
    WHERE ms.aircraftID = aircraft_id
    AND (
        -- Check if flight time overlaps with maintenance period
        (NEW.scheduledDeparture, NEW.scheduledArrival) OVERLAPS 
        (me.startTime, me.startTime + (me.duration || ' hours')::interval)
    );
   
    -- If maintenance is scheduled during flight time, raise an exception
    IF maintenance_count > 0 THEN
        RAISE EXCEPTION 'Cannot assign aircraft to flight: Maintenance scheduled during flight time.
        Aircraft ID: %, Flight Number: %, Scheduled Time: % to %',
        aircraft_id, NEW.flightNumber, NEW.scheduledDeparture, NEW.scheduledArrival;
    END IF;

    -- If no maintenance conflict, allow the flight to be scheduled
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to invoke maintenance schedule check
CREATE TRIGGER check_maintenance_before_flight
BEFORE INSERT OR UPDATE ON aviation_management_schema.Flight
FOR EACH ROW
EXECUTE FUNCTION check_maintence_schedule();

-- Example: Insert a maintenance event (for demonstration)
INSERT INTO aviation_management_schema.MaintenanceEvent 
(aircraftID, aircraftSlotID, airportID, startTime, duration, subsystemCode, eventType, maintenanceReason)
VALUES 
((SELECT aircraftID FROM aviation_management_schema.Aircraft LIMIT 1),
(SELECT slotID FROM aviation_management_schema.AircraftSlot LIMIT 1),
(SELECT airportID FROM aviation_management_schema.Airport LIMIT 1),
'2024-10-15 11:00:00',
2,
'ENG1',
'Scheduled',
'Regular engine maintenance');

-- Example: Insert a flight (which may trigger the maintenance check)
INSERT INTO aviation_management_schema.Flight 
(flightNumber, aircraftSlotID, departureAirportID, arrivalAirportID, 
scheduledDeparture, scheduledArrival, status, availableSeats)
VALUES 
('TEST123', 
(SELECT slotID FROM aviation_management_schema.AircraftSlot LIMIT 1),
(SELECT airportID FROM aviation_management_schema.Airport LIMIT 1),
(SELECT airportID FROM aviation_management_schema.Airport WHERE airportID != 1 LIMIT 1),
'2024-10-15 11:00:00',
'2024-10-15 13:00:00',
'Scheduled',
180);


-- (T2) Customer Feedback Archiving Trigger
/**
    Purpose: Automatically archive customer feedback older than 2 years
    
    Key Functionality:
    - Creates an archive table for old feedback
    - Moves feedback older than 2 years to the archive table
    - Maintains only recent feedback in the main customer table
    - Preserves historical feedback for record-keeping
*/

-- Create archive table to store old feedback
CREATE TABLE CustomerFeedbackArchive (
    customerID INTEGER,
    archivedFeedback JSONB,    -- Stores the old feedback data
    originalTimestamp TIMESTAMP,  -- Original timestamp of the feedback
    archiveDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP  -- When feedback was archived
);

-- Helper function to extract timestamp from feedback
CREATE OR REPLACE FUNCTION get_feedback_timestamp(feedback JSONB)
RETURNS TIMESTAMP AS $$
BEGIN
    -- Assumes feedback has a 'survey_date' field
    RETURN (feedback->>'survey_date')::TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Main archiving function
CREATE OR REPLACE FUNCTION archive_old_feedback()
RETURNS TRIGGER AS $$
DECLARE
    old_feedback JSONB;
    feedback_array JSONB;
    new_feedback JSONB;
    current_feedback JSONB;
    timestamp_to_check TIMESTAMP;
BEGIN
    -- Retrieve current feedback for the customer
    current_feedback := (SELECT customerfeedback FROM customer WHERE customerid = NEW.customerid);
    
    -- Initialize empty feedback array if none exists
    IF current_feedback IS NULL THEN
        current_feedback := '[]'::JSONB;
    END IF;

    -- Initialize new feedback array
    new_feedback := '[]'::JSONB;
    
    -- Iterate through existing feedback entries
    FOR feedback_array IN SELECT * FROM jsonb_array_elements(current_feedback)
    LOOP
        -- Check timestamp of each feedback entry
        timestamp_to_check := get_feedback_timestamp(feedback_array);
        
        -- Archive feedback older than 2 years
        IF timestamp_to_check < (CURRENT_TIMESTAMP - INTERVAL '2 years') THEN
            INSERT INTO CustomerFeedbackArchive (customerID, archivedFeedback, originalTimestamp)
            VALUES (NEW.customerid, feedback_array, timestamp_to_check);
        ELSE
            -- Keep recent feedback
            new_feedback := new_feedback || feedback_array;
        END IF;
    END LOOP;

    -- Add the new feedback to the recent feedback array
    new_feedback := new_feedback || NEW.customerfeedback;
    
    -- Update customer record with only recent feedback
    UPDATE customer 
    SET customerfeedback = new_feedback
    WHERE customerid = NEW.customerid;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to invoke feedback archiving
CREATE TRIGGER trigger_archive_old_feedback
BEFORE UPDATE OF customerfeedback ON customer
FOR EACH ROW
WHEN (NEW.customerfeedback IS NOT NULL)
EXECUTE FUNCTION archive_old_feedback();

-- Example: Update customer feedback
UPDATE customer 
SET customerfeedback = customerfeedback || 
    '[{
        "feedbackId": "123",
        "timestamp": "2024-11-22T10:00:00",
        "rating": 5,
        "comment": "Excellent service",
        "category": "flight"
    }]'::jsonb
WHERE customerid = 1;

-- Verify current customer feedback
select customerfeedback from customer where customerid = 1;

-- Check archived feedback for the customer
select * from CustomerFeedbackArchive cfa
where customerid = 1;