'''(c) isithotrightnow.com by Mat Lipson, Steefan Contractor and James Goldie (2025)

Min loop which is run every 15 minutes to check the latest observations from BOM.
Then if any observations are updated, it invokes the processCurrentObs and processStatsAll lambdas.
'''

import os
from datetime import datetime, timedelta
from pytz import timezone
import numpy as np
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

    # Stations whose bom-id BOM has retired/replaced carry a "fallback_ids"
    # list in locations.json: an ordered list of fallback bom-ids to try
    # scraping instead of the primary one. The first one found in the feed is
    # used, relabelled under the original id so history (ACORN-SAT files,
    # processed stats, plots - all keyed by that id) stays intact. We
    # deliberately don't rename the id itself. Add/edit fallbacks by editing
    # locations.json - no code change needed.
    fallback_station_ids = {
        location["id"]: location["fallback_ids"]
        for location in locations
        if location.get("fallback_ids")}

    station_ids = [location["id"] for location in locations]
    fallback_ids = [fid for fids in fallback_station_ids.values() for fid in fids]
    query_ids = station_ids + fallback_ids
    xpath_filter = " or ".join([f"@bom-id='{station_id}'" for station_id in query_ids])

    def scrape_state(state):
        state_xml_path = f"{bom_xml_path}ID{state}60920.xml"
        # Open the FTP URL and read the XML content
        with urlopen(state_xml_path) as response:
            state_xml = etree.fromstring(response.read())

        obs_list = []
        for station in state_xml.xpath(f"//station[{xpath_filter}]"):
            station_id = station.get("bom-id")
            print("Scraping station: " + str(station_id))
            print(etree.tostring(station))

            try:
                tz = station.get("tz")
                lat = station.get("lat")
                lon = station.get("lon")
                # TODO - would be great to also look at daily tmax/tmin fields
                # here in case a more extreme value happens between updates
                tmax = float(station.xpath(".//element[@type='maximum_air_temperature']")[0].text)
                tmax_dt = station.xpath(".//element[@type='maximum_air_temperature']")[0].get("time-local")
                tmin = float(station.xpath(".//element[@type='minimum_air_temperature']")[0].text)
                tmin_dt = station.xpath(".//element[@type='minimum_air_temperature']")[0].get("time-local")
            # if sth goes wrong, skip the station and move on
            except IndexError as err:
                print("WARNING: skipping " + str(station_id) +
                    " due to an error:")
                print(err)
                continue

            obs_list.append(
                (station_id, tz, lat, lon, tmax, tmax_dt, tmin, tmin_dt))

        print("Scraping complete for state " + state)
        obs_df = pd.DataFrame(obs_list, columns = ["station_id", "tz", "lat",
            "lon", "tmax", "tmax_dt", "tmin", "tmin_dt"])
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

    # resolve any station whose primary bom-id wasn't found in the feed using
    # a configured fallback bom-id instead, if one was found. The fallback's
    # reading gets relabelled under the primary station_id so everything
    # downstream (and all historical continuity) stays keyed the same way.
    found_ids = set(obs_new['station_id'])
    for primary_id, candidate_ids in fallback_station_ids.items():
        if primary_id in found_ids:
            continue
        for candidate_id in candidate_ids:
            candidate_rows = obs_new[obs_new['station_id'] == candidate_id]
            if not candidate_rows.empty:
                print(f"Station {primary_id} not found - using fallback "
                    f"station {candidate_id} in its place")
                resolved_row = candidate_rows.iloc[[0]].copy()
                resolved_row['station_id'] = primary_id
                obs_new = pd.concat([obs_new, resolved_row], ignore_index=True)
                found_ids.add(primary_id)
                break

    # drop rows for fallback bom-ids that aren't themselves tracked stations,
    # so they don't get treated as their own separate station going forward
    obs_new = obs_new[obs_new['station_id'].isin(station_ids)].reset_index(drop=True)

    # find any station that's configured in locations.json but still wasn't
    # found (directly or via a fallback) in any state's feed this cycle
    # (either its bom-id has disappeared entirely, or its XML element is
    # missing the temperature fields and got skipped above) and flag it
    # loudly rather than silently carrying forward stale readings forever
    found_ids = set(obs_new['station_id'])
    missing_ids = [s for s in station_ids if s not in found_ids]
    for missing_id in missing_ids:
        location = next(l for l in locations if l['id'] == missing_id)
        candidate_ids = fallback_station_ids.get(missing_id)
        if candidate_ids:
            print(f"STATION_MISSING: {missing_id} ({location.get('name')}) "
                f"and all of its configured fallbacks ({', '.join(candidate_ids)}) "
                "were not found in any BOM state feed this cycle.")
        else:
            print(f"STATION_MISSING: {missing_id} ({location.get('name')}) was not "
                "found in any BOM state feed this cycle. It may have been "
                "decommissioned or had its bom-id changed - check locations.json, "
                "or add a \"fallback_ids\" entry for it there.")
        flag_missing_station(missing_id, location)

    # just use these obs if we don't have existing ones
    csv_path = f"1-datasources/latest/latest-all.csv"

    # load existing obs, but filter out any stations that have been removed
    # from locations.json (eg. malfunctioning stations)
    obs_old = pd.read_csv(
        download_from_aws(csv_path), dtype = {
            'station_id': str,
            'tmax': float,
            'tmin': float}) \
        .query('station_id in @station_ids')
        
    print("Existing observations, filtered to current statiion list:")
    print(obs_old)

    # Convert datetime columns to datetime objects
    obs_old['tmax_dt'] = pd.to_datetime(obs_old['tmax_dt'])
    obs_old['tmin_dt'] = pd.to_datetime(obs_old['tmin_dt'])

    # Get today's local midnight in UTC
    for row in obs_old.itertuples():
        try: # convert UTC based on stated timezone
            obs_old.loc[row.Index,'today_start_utc'] = pd.Timestamp.now(row.tz).replace(hour=0, minute=0, second=0).astimezone(timezone('UTC'))
        except Exception: # estimate UTC based on longitude
            try:
                # Estimate timezone offset from longitude and create proper datetime
                tz_offset_hours = round(row.lon/15.0)
                # Create a timezone with the estimated offset
                estimated_tz = timezone(timedelta(hours=tz_offset_hours))
                obs_old.loc[row.Index,'today_start_utc'] = pd.Timestamp.now(estimated_tz).replace(hour=0, minute=0, second=0).astimezone(timezone('UTC'))
                print(f"Warning: couldn't convert timezone for {row.station_id}, using estimated timezone based on longitude instead.")
            except Exception: # assume sydney timezone
                obs_old.loc[row.Index,'today_start_utc'] = pd.Timestamp.now('Australia/Sydney').replace(hour=0, minute=0, second=0).astimezone(timezone('UTC'))
                print(f"Warning: couldn't convert timezone for {row.station_id}, using estimated timezone based on Sydney instead")

    # Select new obs if they're more extreme than the previous ones within the last 24 hours
    obs_merged = pd.merge(obs_new, obs_old, on='station_id', how='outer', suffixes=('', '_old'))
    
    # Helper function to safely compare datetime values that might be NaT
    def safe_datetime_compare(dt1, dt2, comparison='<'):
        if pd.isna(dt1) or pd.isna(dt2):
            return False
        if comparison == '<':
            return dt1 < dt2
        elif comparison == '>':
            return dt1 > dt2
        return False
    
    # Helper function to safely compare numeric values that might be NaN
    def safe_numeric_compare(val1, val2, comparison='>='):
        if pd.isna(val1) or pd.isna(val2):
            return False
        if comparison == '>=':
            return val1 >= val2
        elif comparison == '<=':
            return val1 <= val2
        elif comparison == '>':
            return val1 > val2
        elif comparison == '<':
            return val1 < val2
        return False
    
    obs_merged['tmax_selected'] = obs_merged.apply(lambda row: row['tmax'] if safe_numeric_compare(row['tmax'], row['tmax_old'], '>=') or safe_datetime_compare(row['tmax_dt_old'], row['today_start_utc'], '<') else row['tmax_old'], axis=1)
    obs_merged['tmax_selected_dt'] = obs_merged.apply(lambda row: row['tmax_dt'] if safe_numeric_compare(row['tmax'], row['tmax_old'], '>=') or safe_datetime_compare(row['tmax_dt'], row['today_start_utc'], '<') else row['tmax_dt_old'], axis=1)
    obs_merged['tmin_selected'] = obs_merged.apply(lambda row: row['tmin'] if safe_numeric_compare(row['tmin'], row['tmin_old'], '<=') or safe_datetime_compare(row['tmin_dt_old'], row['today_start_utc'], '<') else row['tmin_old'], axis=1)
    obs_merged['tmin_selected_dt'] = obs_merged.apply(lambda row: row['tmin_dt'] if safe_numeric_compare(row['tmin'], row['tmin_old'], '<=') or safe_datetime_compare(row['tmin_dt_old'], row['today_start_utc'], '<') else row['tmin_dt_old'], axis=1)

    # a list to keep track of the updated rows
    updated_list = list(obs_merged.apply(lambda row: safe_numeric_compare(row['tmax'], row['tmax_old'], '>') or safe_numeric_compare(row['tmin'], row['tmin_old'], '<') or safe_datetime_compare(row['tmax_dt_old'], row['today_start_utc'], '<') or safe_datetime_compare(row['tmin_dt_old'], row['today_start_utc'], '<'), axis=1))

    # stations missing from every state's feed this cycle have no genuine new
    # reading - without this, the staleness check above treats their
    # ever-more-outdated old timestamp as "updated" forever, invoking
    # processCurrentObs on every poll with a payload it can't process (eg. no
    # tz), so force those rows to be treated as not updated
    missing_id_set = set(missing_ids)
    updated_list = [
        False if station_id in missing_id_set else updated
        for station_id, updated in zip(obs_merged['station_id'], updated_list)]

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

    # replace NaN with None for forthcoming json dump
    # (json doesn't have NaN, but None in python => null in json)
    obs_result = obs_result.replace({ np.nan: None })

    # invoke processCurrentObs lambda function if tmax/tmix is updated
    for i,updated in enumerate(updated_list):
        if updated or force_update:

            try:
                print('invoking processCurrentObs for station: ',
                    obs_result.iloc[i]['station_id'])
                invoke_processCurrentObs(json.dumps(
                    obs_result.iloc[i].to_dict(),
                    default = convert_timestamp_to_str))
            except Exception as err:
                print("Non-fatal error: " +
                      "failed to invoke processCurrentObs for station " +
                      obs_result.iloc[i]['station_id'] + ". Error was:")
                print(type(err))
                print(err)
            
    # invoke stats_all if any items are updated
    if any(updated_list):
        
        try:
            print('invoking processStatsAll to update combined stats')
            invoke_processStatsAll(json.dumps([]))
        except Exception as err:
            print("Non-fatal error: failed to invoke processStatsAll. " +
                "stats.json may become out of date if this error persists. " +
                "Error was:")
            print(type(err))
            print(err)

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

        print("Upload Successful", url.split('?')[0])
        return url
    except FileNotFoundError:
        print("The file was not found")
        return None

def flag_missing_station(station_id, location):
    '''Merges an error flag into a station's public stats file when it's
    missing from the BOM feed, preserving its last known-good readings so the
    frontend can still show them alongside the error.
    '''

    s3_fpath = f'www/stats/stats_{station_id}.json'
    local_fpath = download_from_aws(s3_fpath)

    if local_fpath is not None:
        with open(local_fpath) as f:
            stats_dict = json.load(f)
    else:
        stats_dict = {}

    stats_dict['isit_name'] = location.get('name')
    stats_dict['isit_label'] = location.get('label')
    stats_dict['isit_error'] = 'station_missing'
    stats_dict['isit_error_message'] = (
        "We're not receiving any BOM data from this station right now! "
        "Hold tight while we investigate.")

    local_out_path = f'/tmp/stats_{station_id}.json'
    with open(local_out_path, 'w') as f:
        json.dump(stats_dict, f)
    upload_to_aws(local_out_path, s3_fpath)
