import os
from datetime import datetime
from pytz import timezone
import pandas as pd
from urllib.request import urlopen
from lxml import etree
import json
import boto3

def lambda_handler(event, context):

    # check if force_upate is in event dictionary key
    if 'force_update' in event:
        force_update = event['force_update']
    else:
        force_update = False

    print("force_update:", force_update)

    print(f"{datetime.now()} Looking for new observations...")

    bom_xml_path = "ftp://ftp.bom.gov.au/anon/gen/fwo/"
    locations_url = f"1-datasources/locations.json"
    # Open the JSON file
    with open(download_from_aws(locations_url)) as file:
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
        obs_df["station_id"] = obs_df["station_id"]
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
    csv_path = f"1-datasources/latest/latest-all.csv"

    obs_old = pd.read_csv(download_from_aws(csv_path), dtype={'station_id': str, 'tmax': float, 'tmin': float})

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

    # a list to keep track of the updated rows
    updated_list = list(obs_merged.apply(lambda row: row['tmax'] > row['tmax_old'] or row['tmin'] < row['tmin_old'] or row['tmax_dt_old'] < row['today_start_utc'] or row['tmin_dt_old'] < row['today_start_utc'], axis=1))

    # Backfill any missing values
    obs_merged['tmax_selected'] = obs_merged['tmax_selected'].fillna(obs_merged['tmax']).fillna(obs_merged['tmax_old'])
    obs_merged['tmax_selected_dt'] = obs_merged['tmax_selected_dt'].fillna(obs_merged['tmax_dt']).fillna(obs_merged['tmax_dt_old'])
    obs_merged['tmin_selected'] = obs_merged['tmin_selected'].fillna(obs_merged['tmin']).fillna(obs_merged['tmin_old'])
    obs_merged['tmin_selected_dt'] = obs_merged['tmin_selected_dt'].fillna(obs_merged['tmin_dt']).fillna(obs_merged['tmin_dt_old'])

    # Select the desired columns
    obs_result = obs_merged[['station_id', 'tz', 'lat', 'lon', 'tmax_selected', 'tmax_selected_dt', 'tmin_selected', 'tmin_selected_dt']]

    # rename columns
    obs_result = obs_result.rename(columns = {'tmax_selected': 'tmax', 'tmax_selected_dt': 'tmax_dt', 'tmin_selected': 'tmin', 'tmin_selected_dt': 'tmin_dt'})

    # Write the result to the CSV file
    obs_result.to_csv(f'/tmp/latest-all.csv', index=False)

    # upload the local file to S3 bucket
    upload_to_aws(f'/tmp/latest-all.csv', csv_path)

    print(str(datetime.now()) + " Wrote out new station observations")

    # invoke processCurrentObs lambda function if tmax/tmix is updated
    for i,updated in enumerate(updated_list):
        if updated or force_update:

            print('invoking processCurrentObs for station: ', obs_result.iloc[i]['station_id'])
            invoke_processCurrentObs(json.dumps(obs_result.iloc[i].to_dict(), default=convert_timestamp_to_str))
            
    # invoke stats_all if any items are updated
    if any(updated_list):
        
        print('invoking processStatsAll to update combined stats')
        invoke_processStatsAll(json.dumps([]))

    return

def convert_timestamp_to_str(data):
    if isinstance(data, pd.Timestamp):
        return data.isoformat()  # Convert to ISO format
    return data

def invoke_processCurrentObs(payload):
    lambda_client = boto3.client('lambda')
    response = lambda_client.invoke(
        FunctionName='processCurrentObs',
        InvocationType='Event',  # This will asynchronously invoke the Lambda function
        Payload=payload
    )
    return response

def invoke_processStatsAll(payload):
    lambda_client = boto3.client('lambda')
    response = lambda_client.invoke(
        FunctionName='processStatsAll',
        InvocationType='Event',  # This will asynchronously invoke the Lambda function
        Payload=payload
    )
    return response


def download_from_aws(s3_fpath):

    s3 = boto3.client('s3')
    bucket_name = 'isithot-data'

    fname = os.path.basename(s3_fpath)
    local_file_path = f'/tmp/{fname}'

    try:
        # Get the object from S3 bucket
        response = s3.get_object(Bucket=bucket_name, Key=s3_fpath)

        # Save the object to local file
        with open(local_file_path, 'wb') as f:
            f.write(response['Body'].read())

        print(f"File saved to {local_file_path}")

        return local_file_path

    except Exception as e:
        print(f"Error getting S3 object: {s3_fpath}")
        return None

def upload_to_aws(local_file, s3_file):

    s3 = boto3.client('s3')
    bucket_name = 'isithot-data'

    try:
        s3.upload_file(local_file, bucket_name, s3_file)
        url = s3.generate_presigned_url(
            ClientMethod='get_object',
            Params={
                'Bucket': bucket_name,
                'Key': s3_file
            },
            ExpiresIn=24 * 3600
        )

        print("Upload Successful", url)
        return url
    except FileNotFoundError:
        print("The file was not found")
        return None
