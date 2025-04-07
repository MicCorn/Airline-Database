from playwright.async_api import async_playwright
from tenacity import retry, stop_after_attempt, wait_fixed
from dataclasses import dataclass
from typing import List, Optional
from datetime import datetime
import asyncio
import json
import os

SELECTORS = {
    "departure_time": 'div.b0EVyb.YMlIz.y52p7d[aria-label^="Departure time"]',
    "flight_num": 'span.Xsgmwe.sI2Nye',
    "airline": 'span.Xsgmwe',
    "price": 'span[data-gs][aria-label$="US dollars"]',
    'departure_time': 'div.b0EVyb.YMlIz.y52p7d',
    'travel_time': 'div.P102Lb.sSHqwe.y52p7d',
    'arrival_time': 'div.OJg28c.YMlIz.y52p7d',
    'arrival_airport': 'div.FY5t7d.tdMWuf.y52p7d',
    'departure_airport': 'div.ZHa2lc.tdMWuf.y52p7d',
    'departure_airport_code': 'div.ZHa2lc.tdMWuf.y52p7d span[dir="ltr"]',
    'arrival_airport_code': 'div.FY5t7d.tdMWuf.y52p7d span[dir="ltr"]',
}
successfully_loaded = [['PUW', 'SEA'], ['SEA', 'PUW'], ['SEA', 'LAX'], ['LAX', 'SEA'], ['SEA', 'MSP'], ['MSP', 'SEA'], ['MSP', 'DLH'], ['DLH', 'MSP'], ['SEA', 'IST'], ['IST', 'SEA'], ['SHA', 'PEK'], ['PEK', 'SHA'], ['SEA', 'PEK'], ['PEK', 'SEA'], ['LAX', 'PEK']]
airport_routes = [['PUW', 'SEA']]
query_dates = ['2024-12-10'] # flee the country the day before the final

async def scrape_google_flights():

    async with async_playwright() as p:
        # Launch browser
        browser = await p.chromium.launch(headless=False)
        context = await browser.new_context()
        page = await context.new_page()

        async def init_setup(page):
            ticket_type_div = page.locator("div.VfPpkd-TkwUic[jsname='oYxtQd']").first
            await ticket_type_div.click()
            await page.wait_for_timeout(300)
            await page.wait_for_selector("ul[aria-label='Select your ticket type.']")
            await page.locator("li").filter(has_text="One way").nth(0).click()
            await page.wait_for_timeout(200)
            await page.locator("body").click()
            await page.wait_for_timeout(250)

        async def departure_arrival(page, depart_airport, arrive_airport):
            await page.keyboard.press("Tab")
            await page.keyboard.press("Tab")
            await page.keyboard.press("Tab")
            await page.keyboard.press("Tab")
            await page.wait_for_timeout(200)
            await page.keyboard.type(depart_airport)
            await page.wait_for_timeout(200)
            await page.keyboard.press("Tab")
            await page.keyboard.press("Tab")
            await page.wait_for_timeout(350)

            # Fill destination
            await page.keyboard.type(arrive_airport)
            await page.wait_for_timeout(300)
            await page.keyboard.press("Tab")
            await page.keyboard.press("Tab")
            await page.wait_for_timeout(700)

        async def select_day(page, date):
            await page.keyboard.type(date)
            await page.wait_for_timeout(700)
            await page.keyboard.press("Enter")
            await page.keyboard.press("Tab")
            await page.keyboard.press("Tab")
            await page.keyboard.press("Enter")
            await page.wait_for_timeout(4000)
        
        async def select_nonstop_flights(page):
            # Click the "Stops" button
            stops_button = page.locator('button[aria-label="Stops, Not selected"]')
            await stops_button.click()
            await page.wait_for_timeout(300)
            # Select "Nonstop only" option
            nonstop_option = page.locator('input[aria-label="Nonstop only"]').first
            await nonstop_option.click()
            await page.wait_for_timeout(300)
            await page.keyboard.press("Escape")
        
        async def main_query_function(page, depart_airport, arrive_airport, date):
            try:
                await init_setup(page)
                await departure_arrival(page, depart_airport, arrive_airport)
                await select_day(page, date)
                print("Page loaded successfully")
                await select_nonstop_flights(page)
            except Exception as e:
                print(f"Error: {e}")
                    
        async def load_all_available_flights(page):
            while True:
                try:
                    # Wait for the "more flights" button
                    more_button = await page.wait_for_selector(
                    'button[aria-label*="more flights"]', timeout=3000
                    )
                    if more_button:
                        await more_button.click()
                        # Wait for new flights to load
                        await page.wait_for_timeout(500)
                    else:
                        break
                except:
                    # No more "Show more" button found
                    break

        async def click_expand_buttons(page):
            expand_buttons = await page.query_selector_all('button[aria-label*="Flight details"]')
            for button in expand_buttons:
                try:
                    await button.click()
                    print(f'clicked button: {button}')
                    await page.wait_for_timeout(3)
                except:
                    # If clicking fails, break
                    print('did not click button, break')
                    break

        async def extract_text(element):
            if element:
                return await element.text_content()
            else:
                return "N/A"

        async def extract_flight_data(page, date):
            print('beginning flight data extraction')
            try:
                await page.wait_for_selector("div.c257Jb.QwxBBf.eWArhb", timeout=3000)

                # Now extract all flight data
                flights = await page.query_selector_all("div.c257Jb.QwxBBf.eWArhb")

                flights_data = []
                for flight in flights:
                    print(f'flight: {flight}')
                    flight_info = {}
                    for key, selector in SELECTORS.items():
                        element = await flight.query_selector(selector)
                        flight_info[key] = await extract_text(element)
                    flight_info['query_date'] = date

                    print(flight_info)

                    flights_data.append(flight_info)
                print(flights_data)

                # extend json if already exists, otherwise json dump
                if os.path.exists("flight_data.txt"):
                    with open("flight_data.txt", "r") as f:
                        existing_data = json.load(f)
                    existing_data.extend(flights_data)
                    with open("flight_data.txt", "w") as f:
                        json.dump(existing_data, f, indent=4)
                else:
                    with open("flight_data.txt", "w") as f:
                        json.dump(flights_data, f, indent=4)

            except Exception as e:
                raise Exception(f"Failed to extract flight data: {str(e)}")


        # print("Navigating to Google Flights...")
        # await page.goto("https://www.google.com/flights", timeout=10000)
        # print("Calling main query function")
        # await main_query_function(page, airport_routes[0][0], airport_routes[0][1], query_dates[0])
        # await load_all_available_flights(page)
        # await click_expand_buttons(page)
        # await extract_flight_data(page, query_dates[0])

        for date in query_dates:
            for route in airport_routes:
                await page.goto("https://www.google.com/flights", timeout=10000)
                depart_airport, arrive_airport = route[0], route[1]
                await main_query_function(page, depart_airport, arrive_airport, date)
                print('loading all available flights')
                await load_all_available_flights(page)
                print('clicking expand buttons')
                await click_expand_buttons(page)
                print('extracting flight data')
                await extract_flight_data(page, date)


# Run the test
if __name__ == "__main__":
    asyncio.run(scrape_google_flights())

