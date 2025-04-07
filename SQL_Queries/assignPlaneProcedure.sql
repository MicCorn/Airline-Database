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

 CALL assignPlane('TK 204', '2024-12-10 19:00:00', @o_tail_no, @message);
 CALL assignPlane('CA 1501', '2024-12-10 08:30:00', @o_tail_no, @message);
SELECT @o_tail_no, @message;
