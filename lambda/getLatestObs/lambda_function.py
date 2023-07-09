import os
from datetime import datetime
from pytz import timezone
import pandas as pd
from urllib.request import urlopen
from lxml import etree
import json

def lambda_handler(event, context):

    print(f"{datetime.now()} Looking for new observations...")

    if os.environ.get("AWS_EXECUTION_ENV") is not None:
        # running on the server
        fullpath = "/mnt/isithotrightnow/"
    else:
        # testing locally
        fullpath = "./"

    bom_xml_path = "ftp://ftp.bom.gov.au/anon/gen/fwo/"
    locations_url = f"{fullpath}www/locations.json"
    # Open the JSON file
    with open(locations_url) as file:
        # Load the JSON data
        locations = json.load(file)

    station_ids = [location["id"] for location in locations]
    xpath_filter = " or ".join([f"@bom-id='{station_id}'" for station_id in station_ids])   

    def scrape_state(state):
        state_xml_path = f"{bom_xml_path}ID{state}60920.xml"
        # Open the FTP URL and read the XML content
        with urlopen(state_xml_path) as response:
            state_xml = etree.fromstring(response.read())

        obs_list = []
        for station in state_xml.xpath(f"//station[{xpath_filter}]"):
            station_id = station.get("bom-id")
            print(station_id)
            tz = station.get("tz")
            lat = station.get("lat")
            lon = station.get("lon")
            tmax = float(station.xpath(".//element[@type='maximum_air_temperature']")[0].text)
            tmax_dt = station.xpath(".//element[@type='maximum_air_temperature']")[0].get("time-local")
            tmin = float(station.xpath(".//element[@type='minimum_air_temperature']")[0].text)
            tmin_dt = station.xpath(".//element[@type='minimum_air_temperature']")[0].get("time-local")
            obs_list.append((station_id, tz, lat, lon, tmax, tmax_dt, tmin, tmin_dt))

        obs_df = pd.DataFrame(obs_list, columns=["station_id", "tz", "lat", "lon", "tmax", "tmax_dt", "tmin", "tmin_dt"])
        obs_df["station_id"] = obs_df["station_id"].astype("int64")
        obs_df["lat"] = obs_df["lat"].astype("float64")
        obs_df["lon"] = obs_df["lon"].astype("float64")
        obs_df["tmax"] = obs_df["tmax"].astype("float64")
        obs_df["tmin"] = obs_df["tmin"].astype("float64")
        obs_df["tmax_dt"] = pd.to_datetime(obs_df["tmax_dt"], utc=True)
        obs_df["tmin_dt"] = pd.to_datetime(obs_df["tmin_dt"], utc=True)
        
        return obs_df

    obs_new = pd.concat([scrape_state(state) for state in ["D", "N", "Q", "S", "T", "V", "W"]], ignore_index=True)

    print(f"{datetime.now()} Downloaded and extracted new observations")

    # just use these obs if we don't have existing ones
    csv_path = os.path.join(fullpath, "data/latest/latest-all.csv")
    if not os.path.exists(csv_path):
        obs_new.to_csv(csv_path, index=False)
        print(str(datetime.now()) + " Wrote out first station observations")
    else:
        obs_old = pd.read_csv(csv_path, dtype={'tmax': float, 'tmin': float})

        # Convert datetime columns to datetime objects
        obs_old['tmax_dt'] = pd.to_datetime(obs_old['tmax_dt'])
        obs_old['tmin_dt'] = pd.to_datetime(obs_old['tmin_dt'])

        # Get today's local midnight in UTC
        tz = [timezone(row_tz) for row_tz in obs_old['tz']]
        obs_old['today_start_utc'] = [datetime.now(row_tz).replace(hour=0, minute=0, second=0).astimezone(timezone('UTC')) for row_tz in tz]

        # Select new obs if they're more extreme than the previous ones within the last 24 hours
        obs_merged = pd.merge(obs_new, obs_old, on='station_id', how='outer', suffixes=('', '_old'))
        obs_merged['tmax_selected'] = obs_merged.apply(lambda row: row['tmax'] if row['tmax'] >= row['tmax_old'] or row['tmax_dt_old'] < row['today_start_utc'] else row['tmax_old'], axis=1)
        obs_merged['tmax_selected_dt'] = obs_merged.apply(lambda row: row['tmax_dt'] if row['tmax'] >= row['tmax_old'] or row['tmax_dt'] < row['today_start_utc'] else row['tmax_dt_old'], axis=1)
        obs_merged['tmin_selected'] = obs_merged.apply(lambda row: row['tmin'] if row['tmin'] <= row['tmin_old'] or row['tmin_dt_old'] < row['today_start_utc'] else row['tmin_old'], axis=1)
        obs_merged['tmin_selected_dt'] = obs_merged.apply(lambda row: row['tmin_dt'] if row['tmin'] <= row['tmin_old'] or row['tmin_dt_old'] < row['today_start_utc'] else row['tmin_dt_old'], axis=1)

        # Backfill any missing values
        obs_merged['tmax_selected'] = obs_merged['tmax_selected'].fillna(obs_merged['tmax']).fillna(obs_merged['tmax_old'])
        obs_merged['tmax_selected_dt'] = obs_merged['tmax_selected_dt'].fillna(obs_merged['tmax_dt']).fillna(obs_merged['tmax_dt_old'])
        obs_merged['tmin_selected'] = obs_merged['tmin_selected'].fillna(obs_merged['tmin']).fillna(obs_merged['tmin_old'])
        obs_merged['tmin_selected_dt'] = obs_merged['tmin_selected_dt'].fillna(obs_merged['tmin_dt']).fillna(obs_merged['tmin_dt_old'])

        # Select the desired columns
        obs_result = obs_merged[['station_id', 'tz', 'lat', 'lon', 'tmax_selected', 'tmax_selected_dt', 'tmin_selected', 'tmin_selected_dt']]

        # Write the result to the CSV file
        obs_result.to_csv(csv_path, index=False)

        print(str(datetime.now()) + " Wrote out new station observations")
