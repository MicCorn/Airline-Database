use airline;

-- Create table with upcoming flights for all passengers, passenger selected on python side
drop view if exists UpcomingFlightsForPassenger;
CREATE VIEW UpcomingFlightsForPassenger AS
SELECT p.passenger_id, CONCAT(p.f_name, ' ', p.l_name) AS full_name, b.flight_id, f.departure_datetime, f.departure_airport, f.arrival_airport, f.airline_id, f.tail_no, f.international, f.duration, b.seat_number, b.status AS booking_status
FROM passenger p
JOIN booking b ON p.passenger_id = b.passenger_id
JOIN flight f ON b.flight_id = f.flight_id AND b.departure_datetime = f.departure_datetime
WHERE f.departure_datetime > NOW()
ORDER BY f.departure_datetime ASC;

-- Count # of airports in each country
SELECT country, COUNT(country) AS airport_count
FROM airport as a
GROUP BY country
ORDER BY airport_count DESC;

-- Determine 'top 5 most connected countries' by number of airlines
SELECT country, COUNT(country) as airline_count
FROM airline as airl
GROUP BY country
ORDER BY airline_count DESC
LIMIT 5;

-- some of these crew salaries look pretty low. It's almost like they're all in 2005 values. Michael, do you have anything to say on that?
CREATE OR REPLACE VIEW Crew_Salary_Metrics AS
WITH ordered_salary_numbers AS (
	SELECT salary, ROW_NUMBER() OVER (ORDER BY salary) AS ordered_rownum, -- adds salary to each row
    COUNT(*) OVER () AS total_count -- adds total_count to each row -- thes functions that require OVER are called window functions --> probably the only way to do this
	FROM crew),
quartile_calc AS (
	SELECT
		(SELECT salary FROM ordered_salary_numbers WHERE ordered_rownum = FLOOR((total_count + 1) / 4)) AS quart_1_salary,
        (SELECT salary FROM ordered_salary_numbers WHERE ordered_rownum = FLOOR((3 * total_count + 3) / 4)) AS quart_3_salary
        FROM ordered_salary_numbers
        LIMIT 1),
median_calc AS (
	SELECT
    CASE
		WHEN total_count % 2 = 1 THEN -- if odd #
			(SELECT salary FROM ordered_salary_numbers WHERE ordered_rownum = (total_count DIV 2) + 1) -- integer division, but '/' also works for this line
		ELSE -- if even # here
			(SELECT AVG(salary) FROM ordered_salary_numbers WHERE ordered_rownum IN ((total_count DIV 2), (total_count DIV 2) + 1)) -- need to use DIV -> it's integer division :(
		END
        AS median_salary
	FROM ordered_salary_numbers
    LIMIT 1)
SELECT
	MIN(salary) as min_salary,
	MAX(salary) as max_salary,
	TRUNCATE(MAX(salary) - MIN(salary), 2) as salary_range,
	COUNT(salary) as total_count,
    TRUNCATE(AVG(salary), 2) as avg_salary,
    (SELECT quart_1_salary FROM quartile_calc) AS Q1_Salary,
    TRUNCATE((SELECT median_salary FROM median_calc), 2) as Median_Salary,
    (SELECT quart_3_salary FROM quartile_calc) AS Q3_Salary
FROM crew;


SELECT *
FROM Crew_Salary_Metrics;

-- Procedure to give all pilots raises. Average pilot salary is $113,080. However, I now see that my view only works for all salaries, and not just for pilots.
CREATE OR REPLACE VIEW Crew_Salary_Metrics_By_Role AS
WITH ordered_salary_numbers AS (
    SELECT 
        role,
        salary,
        ROW_NUMBER() OVER (PARTITION BY role ORDER BY salary) AS ordered_rownum, -- Partition by role
        COUNT(*) OVER (PARTITION BY role) AS total_count -- Partition by role
    FROM crew
),
quartile_calc AS (
    SELECT 
        role,
        -- Q1
        (SELECT salary 
         FROM ordered_salary_numbers osn 
         WHERE osn.role = o.role AND ordered_rownum = FLOOR((total_count + 1) / 4)) AS quart_1_salary,
        -- Q3
        (SELECT salary 
         FROM ordered_salary_numbers osn 
         WHERE osn.role = o.role AND ordered_rownum = FLOOR((3 * total_count + 3) / 4)) AS quart_3_salary
    FROM ordered_salary_numbers o
    GROUP BY role
),
median_calc AS (
    SELECT 
        role,
        CASE
            WHEN total_count % 2 = 1 THEN 
                -- Median for odd total_count
                (SELECT salary 
                 FROM ordered_salary_numbers osn 
                 WHERE osn.role = o.role AND ordered_rownum = (total_count DIV 2) + 1)
            ELSE
                -- Median for even total_count
                (SELECT AVG(salary) 
                 FROM ordered_salary_numbers osn 
                 WHERE osn.role = o.role AND ordered_rownum IN ((total_count DIV 2), (total_count DIV 2) + 1))
        END AS median_salary
    FROM ordered_salary_numbers o
    GROUP BY role
)
SELECT
    role,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary,
    TRUNCATE(MAX(salary) - MIN(salary), 2) AS salary_range,
    COUNT(salary) AS total_count,
    TRUNCATE(AVG(salary), 2) AS avg_salary,
    (SELECT quart_1_salary FROM quartile_calc qc WHERE qc.role = c.role) AS Q1_Salary,
    TRUNCATE((SELECT median_salary FROM median_calc mc WHERE mc.role = c.role), 2) AS Median_Salary,
    (SELECT quart_3_salary FROM quartile_calc qc WHERE qc.role = c.role) AS Q3_Salary
FROM crew c
GROUP BY role;


SELECT * 
FROM Crew_Salary_Metrics_By_Role;



-- Return a table of flights with the shortest layover times (hardest connections to make). We can use this list to force people to miss their connections :)
WITH flight_pairs AS (
    SELECT f1.flight_id AS first_flight_id, f1.arrival_airport AS layover_airport, f2.flight_id AS second_flight_id, TIMESTAMPDIFF(MINUTE, f1.arrival_datetime, f2.departure_datetime) AS layover_duration
    FROM flight f1 JOIN flight f2
    ON f1.arrival_airport = f2.departure_airport AND f1.arrival_datetime < f2.departure_datetime
    WHERE TIMESTAMPDIFF(MINUTE, f1.arrival_datetime, f2.departure_datetime) > 0
)
SELECT first_flight_id, second_flight_id, layover_airport, layover_duration
FROM flight_pairs
ORDER BY layover_duration ASC;
