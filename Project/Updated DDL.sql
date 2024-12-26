USE airline;

-- Table: countries
CREATE TABLE countries (
   country VARCHAR(50) PRIMARY KEY
);

-- Table: airport
CREATE TABLE airport (
    code CHAR(3) PRIMARY KEY,
    airport_name VARCHAR(100) NOT NULL,
    city VARCHAR(50),
	country VARCHAR(50) NOT NULL,
    FOREIGN KEY (country) REFERENCES countries(country)
);

-- Table: airline
CREATE TABLE airline (
    airline_id CHAR(3) PRIMARY KEY,
    airline_name VARCHAR(100) NOT NULL,
    country VARCHAR(50),
    FOREIGN KEY (country) REFERENCES countries(country)
);

-- Table: passenger
CREATE TABLE passenger (
    passenger_id INT AUTO_INCREMENT PRIMARY KEY,
    f_name VARCHAR(50) NOT NULL,
    l_name VARCHAR(50) NOT NULL,
    dob DATE NOT NULL,
    passport_no VARCHAR(20) UNIQUE
);


-- Table: crew
CREATE TABLE crew (
    crew_id INT AUTO_INCREMENT PRIMARY KEY,
    f_name VARCHAR(50) NOT NULL,
    l_name VARCHAR(50) NOT NULL,
    role VARCHAR(50),
    license_no VARCHAR(50) UNIQUE,
	airline_id CHAR(3) NOT NULL,
    salary NUMERIC(10, 2) NOT NULL,
    code CHAR(3),
	FOREIGN KEY (airline_id) REFERENCES airline(airline_id),
    FOREIGN KEY (code) REFERENCES airport(code)
);


-- Table: aircraft
CREATE TABLE aircraft (
    tail_no VARCHAR(8) PRIMARY KEY,
    model VARCHAR(50) NOT NULL,
    manufacturing_year YEAR NOT NULL,
    capacity INT NOT NULL CHECK (capacity >= 0),
	airline_id CHAR(3) NOT NULL,
    FOREIGN KEY (airline_id) REFERENCES airline(airline_id)
);

-- Table: maintenance_record
CREATE TABLE maintenance_record (
    record_id INT AUTO_INCREMENT PRIMARY KEY,
    tail_no VARCHAR(8) NOT NULL,
    maintenance_date DATE NOT NULL,
    description MEDIUMTEXT,
    FOREIGN KEY (tail_no) REFERENCES aircraft(tail_no)
);

-- Table: flight
CREATE TABLE flight (
    flight_id VARCHAR(10),
	departure_airport CHAR(3) NOT NULL,
    arrival_airport CHAR(3) NOT NULL,
    departure_datetime TIMESTAMP NOT NULL,
    arrival_datetime TIMESTAMP NOT NULL,
    duration INT NOT NULL,
    airline_id CHAR(3) NOT NULL,
    international BOOLEAN,
    tail_no VARCHAR(8),
    PRIMARY KEY (flight_id, departure_datetime),
    FOREIGN KEY (airline_id) REFERENCES airline(airline_id),
    FOREIGN KEY (tail_no) REFERENCES aircraft(tail_no),
	FOREIGN KEY (departure_airport) REFERENCES airport(code),
	FOREIGN KEY (arrival_airport) REFERENCES airport(code)
);

-- Table: booking (weak entity set)
CREATE TABLE booking (
    flight_id VARCHAR(10),
    departure_datetime TIMESTAMP,
    passenger_id INT,
    booking_date TIMESTAMP NOT NULL,
    travel_class VARCHAR(20),
    seat_number VARCHAR(10),
    carry_on BOOLEAN,
    checked INT CHECK (checked >= 0) DEFAULT 0,
    status VARCHAR(20),
    price NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY (flight_id, departure_datetime, passenger_id),
    FOREIGN KEY (flight_id, departure_datetime) REFERENCES flight(flight_id, departure_datetime),
    FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id)
);

-- Tables: passenger_contact_info (multivalued attribute)
CREATE TABLE passenger_contact_phone (
    passenger_id INT,
    phone VARCHAR(18),
    PRIMARY KEY (passenger_id, phone),
    FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id)
);

CREATE TABLE passenger_contact_email (
    passenger_id INT,
    email VARCHAR(100),
    PRIMARY KEY (passenger_id, email),
    FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id)
);

CREATE TABLE passenger_contact_address (
    passenger_id INT,
    address VARCHAR(200),
    PRIMARY KEY (passenger_id, address),
    FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id)
);

-- Relationship Tables

CREATE TABLE assigned (
    crew_id INT,
    flight_id VARCHAR(10),
    departure_datetime TIMESTAMP,
    PRIMARY KEY (crew_id, flight_id, departure_datetime),
    FOREIGN KEY (crew_id) REFERENCES crew(crew_id),
    FOREIGN KEY (flight_id, departure_datetime) REFERENCES flight(flight_id, departure_datetime)
);

-- Triggers
DELIMITER $$

CREATE TRIGGER set_international_flag
BEFORE INSERT ON flight
FOR EACH ROW
BEGIN
    DECLARE dep_country VARCHAR(50);
    DECLARE arr_country VARCHAR(50);

    SELECT country INTO dep_country FROM airport WHERE code = NEW.departure_airport;
    SELECT country INTO arr_country FROM airport WHERE code = NEW.arrival_airport;

    SET NEW.international = (dep_country != arr_country);
END$$

CREATE TRIGGER enforce_checked_baggage
BEFORE INSERT ON booking
FOR EACH ROW
BEGIN
    DECLARE is_international BOOLEAN;

    -- Check if the flight is international
    SELECT international INTO is_international
    FROM flight
    WHERE flight_id = NEW.flight_id AND departure_datetime = NEW.departure_datetime;

    IF is_international THEN
        -- If international, set checked baggage to at least 1
        IF NEW.checked < 1 THEN
            SET NEW.checked = 1;
        END IF;
    ELSE
        -- If domestic, set checked baggage to 0
        SET NEW.checked = 0;
    END IF;
END$$

DELIMITER ;

