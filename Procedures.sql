
drop procedure if exists addPassengerBooking;

DELIMITER //

CREATE PROCEDURE AddPassengerBooking(
    IN p_flight_id VARCHAR(10),
    IN p_departure_datetime TIMESTAMP,
    IN p_passenger_id INT,
    IN p_booking_date TIMESTAMP,
    IN p_travel_class VARCHAR(20),
    IN p_seat_number VARCHAR(10),
    IN p_carry_on BOOLEAN,
    IN p_checked INT,
    IN p_status VARCHAR(20),
    IN p_price NUMERIC(10, 2)
)
BEGIN
    INSERT INTO booking (flight_id, departure_datetime, passenger_id, booking_date, travel_class, 
                         seat_number, carry_on, checked, status, price)
    VALUES (p_flight_id, p_departure_datetime, p_passenger_id, p_booking_date, p_travel_class, 
            p_seat_number, p_carry_on, p_checked, p_status, p_price);
END //

DELIMITER ;


-- ------ Assign Crew ----------------

drop procedure if exists assignAvailableCrew;

DELIMITER $$

CREATE PROCEDURE assignAvailableCrew(
    IN p_flight_id VARCHAR(10),
    IN p_departure_datetime TIMESTAMP
)
proc_label:BEGIN
    DECLARE num_pilots INT;
    DECLARE num_attendants INT;
    DECLARE needed_pilots INT DEFAULT 2;
    DECLARE needed_attendants INT DEFAULT 5;
    DECLARE remaining_pilots INT;
    DECLARE remaining_attendants INT;
    DECLARE crew_added INT DEFAULT 0;
    DECLARE flight_airline_id CHAR(3);
    DECLARE flight_departure_airport CHAR(3);

    -- Check current crew assigned to the flight
    SELECT COUNT(*) 
    INTO num_pilots
    FROM assigned a
    JOIN crew c ON a.crew_id = c.crew_id
    WHERE a.flight_id = p_flight_id 
	AND a.departure_datetime = p_departure_datetime
	AND c.role = 'Pilot';

    SELECT COUNT(*) 
    INTO num_attendants
    FROM assigned a
    JOIN crew c ON a.crew_id = c.crew_id
    WHERE a.flight_id = p_flight_id 
	AND a.departure_datetime = p_departure_datetime
	AND c.role = 'Flight Attendant';

    -- Check if crew requirements are already met
    IF num_pilots >= needed_pilots AND num_attendants >= needed_attendants THEN
        SELECT CONCAT('Crew already assigned to flight ', p_flight_id, ' on ', p_departure_datetime) AS message;
        LEAVE proc_label;
    END IF;

    -- Calculate remaining crew needed
    SET remaining_pilots = needed_pilots - num_pilots;
    SET remaining_attendants = needed_attendants - num_attendants;

    -- Get the airline and departure airport of the selected flight
    SELECT airline_id, departure_airport INTO flight_airline_id, flight_departure_airport
    FROM flight
    WHERE flight_id = p_flight_id AND departure_datetime = p_departure_datetime;

    -- Step 2: Assign crew based on closest airport (crew.code matches flight.departure_airport)
    IF remaining_pilots > 0 THEN
        INSERT INTO assigned (crew_id, flight_id, departure_datetime)
        SELECT c.crew_id, p_flight_id, p_departure_datetime
        FROM crew c
        WHERE c.code = flight_departure_airport
		AND c.role = 'Pilot'
		AND c.airline_id = flight_airline_id
		AND NOT EXISTS (
              SELECT 1
              FROM assigned a
              JOIN flight f ON a.flight_id = f.flight_id AND a.departure_datetime = f.departure_datetime
              WHERE a.crew_id = c.crew_id
			AND f.arrival_datetime > p_departure_datetime
		)
        LIMIT remaining_pilots;

        SET crew_added = crew_added + ROW_COUNT();
    END IF;

    IF remaining_attendants > 0 THEN
        INSERT INTO assigned (crew_id, flight_id, departure_datetime)
        SELECT c.crew_id, p_flight_id, p_departure_datetime
        FROM crew c
        WHERE c.code = flight_departure_airport
		AND c.role = 'Flight Attendant'
		AND c.airline_id = flight_airline_id
		AND NOT EXISTS (
              SELECT 1
              FROM assigned a
              JOIN flight f ON a.flight_id = f.flight_id AND a.departure_datetime = f.departure_datetime
              WHERE a.crew_id = c.crew_id
			AND f.arrival_datetime > p_departure_datetime
		)
        LIMIT remaining_attendants;

        SET crew_added = crew_added + ROW_COUNT();
    END IF;

    -- Update the crew's location based on the arrival airport of the assigned flight
    UPDATE crew c
    JOIN assigned a ON c.crew_id = a.crew_id
    JOIN flight f ON a.flight_id = f.flight_id AND a.departure_datetime = f.departure_datetime
    SET c.code = f.arrival_airport
    WHERE a.flight_id = p_flight_id AND a.departure_datetime = p_departure_datetime;

    -- Final check for remaining requirements
    SET remaining_pilots = needed_pilots - (num_pilots + crew_added);
    SET remaining_attendants = needed_attendants - (num_attendants + crew_added);

    -- Output success or failure message
    IF remaining_pilots > 0 OR remaining_attendants > 0 THEN
        SELECT CONCAT('Not enough crew members were found. Flight ', p_flight_id,
                      ' on ', p_departure_datetime, ' is missing ', 
                      remaining_pilots, ' pilots and ', 
                      remaining_attendants, ' flight attendants.') AS message;
    ELSE
        SELECT CONCAT('Success! Flight ', p_flight_id, ' on ', p_departure_datetime,
                      ' was filled with ', crew_added, ' crew members.') AS message;
    END IF;
END$$

DELIMITER ;

call airline.assignAvailableCrew('UA 1400', '2024-12-10 6:25');
call airline.assignAvailableCrew('UA 1657', '2024-12-10 19:30');

-- Similarly, we need a way to assign planes to flights. The priority is much the same as crew:
-- - Planes belonging to the same airline that the flight is on
-- - Planes that are not scheduled to be airborne at the time of flight departure, or having times that conflict
-- - Planes large enough to accomadate the number of bookings on the flight
-- - Planes that are currently at the airport of departure

drop procedure if exists assignPlane;
DELIMITER $$

CREATE PROCEDURE assignPlane(
	in i_flight_id VARCHAR(10), 
    in i_departure_datetime TIMESTAMP, 
    out o_tail_no VARCHAR(8),
    out message VARCHAR(60)
)
	BEGIN
		DECLARE done INT DEFAULT FALSE;
		DECLARE required_airlineID CHAR(3);
		DECLARE required_Capacity INT;
        DECLARE required_depAirport CHAR(3);
        DECLARE tailNo VARCHAR(8);
		DECLARE airlineID CHAR(3);
        DECLARE aircraftCapacity INT;
        -- DECLARE lastArrival CHAR(3);
        DECLARE score INT;
        DECLARE bestScore INT DEFAULT -1;
        
        DECLARE aircraft_cursor CURSOR FOR SELECT tail_no, capacity, airline_id FROM aircraft;
        
		DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
        
        select count(distinct passenger_id) into required_Capacity
		from booking
		where flight_id = i_flight_id and departure_datetime = i_departure_datetime;
         
		select airline_id, departure_airport into required_airlineID, required_depAirport
        from flight
        where flight_id = i_flight_id and departure_datetime = i_departure_datetime; 
        
        select tail_no into o_tail_no
        from flight
        where flight_id = i_flight_id and departure_datetime = i_departure_datetime; 
        
        IF o_tail_no IS NOT NULL THEN
			SET done = true;
		END IF;
         
        OPEN aircraft_cursor;
        
        read_loop: LOOP
			FETCH aircraft_cursor INTO tailNo, aircraftCapacity, airlineID;
        
			IF done THEN 
            LEAVE read_loop;
			END IF;
        
			SET score = 0;
            
            IF aircraftCapacity >= required_Capacity THEN
				SET score = score + 1;
			END IF;
            
            IF airlineID = required_airlineID THEN
				SET score = score + 1;
			END IF;
            
            IF score > bestScore THEN 
				SET bestScore = score;
                SET o_tail_no = tailNo;
			END IF;
			
		END LOOP;
	
		CLOSE aircraft_cursor;
        
        SELECT CONCAT('Assigned aircraft with tail_no ', o_tail_no, ' to flight ', i_flight_id) into message;
        
        UPDATE flight
		SET tail_no = o_tail_no
		WHERE flight_id = i_flight_id;
        
	END $$
    


DELIMITER ;

CALL assignPlane('TK 204', '2024-12-10 19:00', @o_tail_no, @message);
CALL assignPlane('CA 1501', '2024-12-10 08:30', @o_tail_no, @message);
SELECT @o_tail_no, @message;

DELIMITER $$

CREATE PROCEDURE RemoveOldAircraft()
BEGIN
    DELETE FROM aircraft
    WHERE tail_no in (
		select tail_no
		from (
			select tail_no 
			from aircraft 
            where manufacturing_year <= (YEAR(NOW()) - 35) 
		) as old_aircraft
        );
END $$

DELIMITER ;


-- Let's create a procedure to update salary by role, where we input a percent raise w/ a role, and it raises that salary the appropriate amount
DROP PROCEDURE IF EXISTS UpdateSalaryByRole;
DROP PROCEDURE IF EXISTS GiveAllRolesRaises;

DELIMITER $$
CREATE PROCEDURE UpdateSalaryByRole(
	IN role_name VARCHAR(50),
    IN percent_increase DECIMAL(6, 2))
BEGIN
	UPDATE crew
    SET salary = TRUNCATE(salary + (salary * (percent_increase / 100)), 2)
    WHERE role = role_name;
END$$

CREATE PROCEDURE GiveAllRolesRaises(
    IN percent_increase DECIMAL(5, 2))
BEGIN
	UPDATE crew
    SET salary = TRUNCATE(salary + (salary * (percent_increase / 100)), 2);
END$$
DELIMITER ;

-- need to give all the pilots a 6250% raise to bring the median to approximately 100,000/year
CALL UpdateSalaryByRole('Pilot', 6250);
-- Let's give the other roles around a 3000% raise, and air traffic control a 4000% raise
CALL UpdateSalaryByRole('Airfield', 3500);
CALL UpdateSalaryByRole('Gate Agent', 2500);
CALL UpdateSalaryByRole('Air Traffic Control', 4000);
CALL UpdateSalaryByRole('Flight Attendant', 3000);

SELECT * 
FROM Crew_Salary_Metrics_By_Role;

-- Now let's give all roles a 12.5% increase across the board to keep up with rampant inflation
CALL GiveAllRolesRaises(8.5);

SELECT * 
FROM Crew_Salary_Metrics_By_Role;

-- One time salary to give a 10% raise to those making <40,000, but to cap the total income at 40,000
UPDATE crew
SET salary = LEAST(salary + (salary * 0.10), 40000)
WHERE salary < 40000;

SELECT * 
FROM Crew_Salary_Metrics_By_Role;

-- create procedure to return highest and lowest salary using a cursor
DROP PROCEDURE IF EXISTS GetHighLowSalaryWithCursor;
DELIMITER $$
CREATE PROCEDURE GetHighLowSalaryWithCursor(
	INOUT highest_salary DECIMAL(10,2),
    INOUT lowest_salary DECIMAL(10,2)
)
BEGIN
	DECLARE current_salary DECIMAL(10,2);
    DECLARE done INT DEFAULT 0;
    
    DECLARE temp_highest_salary DECIMAL(10,2) DEFAULT NULL;
    DECLARE temp_lowest_salary DECIMAL(10,2) DEFAULT NULL;
    
    DECLARE salary_cursor CURSOR FOR SELECT salary FROM crew;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
    
    OPEN salary_cursor;
    WHILE done = 0 DO
		FETCH salary_cursor INTO current_salary;
        
        IF temp_highest_salary IS NULL OR current_salary > temp_highest_salary THEN
			SET temp_highest_salary = current_salary;
		END IF;
        
        IF temp_lowest_salary IS NULL or current_salary < temp_lowest_salary THEN
			SET temp_lowest_salary = current_salary;
		END IF;
	END WHILE;
    CLOSE salary_cursor;
    
    SET highest_salary = temp_highest_salary;
    SET lowest_salary = temp_lowest_salary;
END$$
DELIMITER ;

CALL GetHighLowSalaryWithCursor(@highest_salary, @lowest_salary);
SELECT @highest_salary as HighestSalary, @lowest_salary as LowestSalary;

-- Find the 'busiest' airport

DROP FUNCTION IF EXISTS GetBusiestAirport;
DELIMITER $$
CREATE FUNCTION GetBusiestAirportString()
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
	DECLARE return_val VARCHAR(255);
    
    SELECT CONCAT(a.airport_name, ' (', a.code, ') ---> ', COUNT(f.flight_id), ' flights')
    INTO return_val
    FROM airport AS a
    LEFT JOIN flight f ON f.departure_airport = a.code
    GROUP BY a.code, a.airport_name
    ORDER BY COUNT(f.flight_id) DESC
    LIMIT 1;
    
    RETURN return_val;
END $$
DELIMITER ;

SELECT GetBusiestAirportString() AS busiest_airport;