# Airline Database
A flight systems database backend, written primarily for implementation with MySQL. This project was completed through the joint collaboration of Colden Johnson, Michael Cornell, and Ethan 'Cobbe' Deal. This is intended to provide a 'proof of concept' alternative to currently existing airline database systems.

View our final report here: https://www.overleaf.com/read/crcvgzbmywbm#b8dd37

This project requires a tiny bit of setup. First, please ensure all the proper packages are installed on your machine:

pymysql
playwright
tenacity
dataclasses (built-in for Python 3.7+; no need to install separately unless using an older version)
nest-asyncio
tabulate
network

For the web scraping, it may be necessary to run "playwright install" as well.

Next, this project hosts the SQL server locally, so kindly enter the authentication information for your localhost server. The program should automatically request a password, but if this fails to connect to the server, you can modify the following code:

# Connect to server
host="localhost"
user="root"
password="XXXXXXXXX"

Finally, when the terminal is run, the user can choose to either scrape flights or access airline database.

For flight scraping, we have seen the most success when a VPN is used. Due to geographical location and google flights traffic monitoring, the connection might time out and crash the terminal. In an ideal situation, however, the code should work. 

To access the airline database interaction terminal, enter the username "admin" and the ultra-secure password "123". These are top secret, so please don't tell anyone...

The terminal occasionally lags and doesn't display the most recent table or instruction, so if this happens, proceed with any required inputs or press enter to load any necessary tables.

Here is the user manual for the airline database terminal:

Basic information fetching:
0. Exit terminal
1. View all flights
2. View flights by airline, input airline
3. View flights to and from specified airports, input one, two, or zero airports
4. Find shortest route between two specified airports, input two airports
5. View crew working for specified airline, input airline
6. View all maintenance records
7. View all maintenance record for specified aircraft, input tail number
8. View upcoming flights for specified passenger, input passenger ID
9. View crew assignment table
10. View crew members assigned to specified flight, input flight information
Statistics:
11. View airport count by country
12. View most connected countries by number of airports, input number of countries to display
13. View crew salary metrics
14. View crew salary metrics by role
15. View highest and lowest salary
16. View shortest layovers, input number of layovers to display
17. View busiest airport
Assignment:
18. Manually add passenger booking, input all booking parameters
19. Assign available crew to specified flight, input flight information
20. Assign aircraft to specified flight, input flight information
Maintenance:
21. Remove old aircraft
22. Give all crew raises, input percent increase
23. Give all crew under specified role raises, input role name, percent increase
