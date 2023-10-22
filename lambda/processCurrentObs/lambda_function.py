import pandas as pd
import numpy as np
import json
import boto3
import os
from datetime import datetime
from pytz import timezone

def get_current_obs(req_station_id, fileid):
    # Returns a data frame with the max and min temps reported by the station
    dtypes = {'station_id': str, 'tmax': float, 'tmin': float}
    df = pd.read_csv(fileid, dtype=dtypes)
    df = df[df['station_id'] == req_station_id][['tmax', 'tmin']]
    print(df)
    return df

def calc_hist_percentiles(Obs):
    # Returns a data frame with columns Tmax, Tmin and Tavg, each row referring to the 6 percentiles:
    # 5, 10, 40, 50, 60, 90, 95
    if Obs is None:
        raise ValueError("Error: Missing historical observations")
    obs_cols = Obs.drop(columns=['Date', 'Year', 'Month', 'Day'])
    percentiles = np.array([0.05, 0.1, 0.4, 0.5, 0.6, 0.9, 0.95])
    result = obs_cols.quantile(percentiles, axis=0, numeric_only=True)
    result.columns = ['Tmax', 'Tmin', 'Tavg']
    return result

def determine_answer_and_comment(category_now):
    switcher_answer = {
        'bc': 'Hell no!',
        'rc': 'No!',
        'c': 'Nope',
        'a': 'Not really',
        'h': 'Yup',
        'rh': 'Yeah!',
        'bh': 'Hell yeah!'
    }
    isit_answer = switcher_answer.get(category_now, 'Invalid category')

    switcher_comment = {
        'bc': "Are you kidding?! It's bloody cold",
        'rc': "It's actually really cold",
        'c': "It's actually kinda cool",
        'a': "It's about average",
        'h': "It's warmer than average",
        'rh': "It's really hot!",
        'bh': "It's bloody hot!"
    }
    isit_comment = switcher_comment.get(category_now, 'Invalid category')

    return isit_answer, isit_comment

def bin_obs(tavg_now, hist_percentiles):
    return pd.cut([tavg_now],
        bins=[
            -100,
            *hist_percentiles.loc[hist_percentiles.index != 0.5, "Tavg"],
            100
        ],
        labels=["bc", "rc", "c", "a", "h", "rh", "bh"],
        include_lowest=True,
        right=False
    ).astype(str)[0]
    # The -100 and 100 allow us to have the lowest and highest bins

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
        print(f"Error getting S3 object: {e}")
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

def invoke_plotting_lambda(fn_name, payload):
    lambda_client = boto3.client('lambda')
    response = lambda_client.invoke(
        FunctionName=fn_name,
        InvocationType='Event',
        Payload=json.dumps(payload)
    )
    return response

def lambda_handler(event, context):

    station_id, tz, lat, lon, tmax_now, tmax_dt, tmin_now, tmin_dt = event.values()
    print(event.values())
    print(f"\n\nBeginning analysis: {station_id}")

    # Load station data from locations.json
    loc_s3_fpath = f'1-datasources/locations.json'
    local_fpath = download_from_aws(loc_s3_fpath)
    with open(local_fpath) as f:
        station_set = json.load(f)
    this_station = [s for s in station_set if s['id'] == station_id][0]

    # Get current date and time
    current_date_time = datetime.now(timezone(tz))
    current_date = current_date_time.date()

    # Calculate tavg from current tmax and tmin
    tavg_now = np.mean([tmax_now,tmin_now]).round()
    print(f"Updating station: {station_id}")
    print(f"Tavg.now = {tavg_now}")

    # Calculate percentiles of historical data
    # Read historical tmin obs from s3
    s3_fpath = f"2-processed/historical_{station_id}.txt"
    local_fpath = download_from_aws(s3_fpath)
    hist_obs = pd.read_csv(local_fpath,
                           na_values=["", " ", "NA"])
    hist_percentiles = calc_hist_percentiles(hist_obs)

    # Determine category of current temperature based on percentiles
    category_now = bin_obs(tavg_now, hist_percentiles)

    # Determine answer and comment based on category
    isit_answer, isit_comment = determine_answer_and_comment(category_now)

    # find where current temp falls in historical distribution
    ecdf = hist_obs['Tavg'].sort_values().dropna().searchsorted(tavg_now)/len(hist_obs['Tavg'].dropna())

    if tavg_now <= min(hist_obs['Tavg']):
        average_percent = 0.
    elif tavg_now > max(hist_obs['Tavg']):
        average_percent = 100.
    else:
        average_percent = 100 * np.round(ecdf, 3)

    # Save updated stats to file
    # Create stats dictionary
    stats_dict = {}
    stats_dict['isit_answer'] = isit_answer if isit_answer else None
    stats_dict['isit_comment'] = isit_comment if isit_comment else None
    stats_dict['isit_maximum'] = tmax_now if tmax_now else None
    stats_dict['isit_minimum'] = tmin_now if tmin_now else None
    stats_dict['isit_current'] = tavg_now if tavg_now else None
    stats_dict['isit_average'] = average_percent if average_percent else None
    stats_dict['isit_name'] = this_station['name'] if 'name' in this_station else None
    stats_dict['isit_label'] = this_station['label'] if 'label' in this_station else None
    if 'record_start' in this_station and 'record_end' in this_station:
        stats_dict['isit_span'] = f"{this_station['record_start']} - {this_station['record_end']}"
    else:
        stats_dict['isit_span'] = None

    file_path = f'/tmp/stats_{station_id}.json'
    # Write the stats dictionary to the JSON file
    with open(file_path, "w") as f:
        json.dump(stats_dict, f)
    upload_to_aws(file_path, f'www/stats/stats_{station_id}.json')
    
    # invoke time series plotting function
    invoke_plotting_lambda(
        "createTimeseriesPlot",
        {
            "hist_obs": hist_obs.to_json(orient="records"),
            "tavg_now": tavg_now,
            "station_id": station_id,
            "station_tz": tz,
            "station_label": this_station['label']})

    # invoke distribution plotting function
    invoke_plotting_lambda(
        "createDistributionPlot",
        {
            "hist_obs": hist_obs.to_json(orient="records"),
            "tavg_now": tavg_now,
            "station_id": station_id,
            "station_tz": tz,
            "station_label": this_station['label']})
    
    ##### heatwave plotting function ######

    # read and write yearly percentiles for heatmap (station-id_year.csv)
    s3_fname = f"2-processed/{station_id}-{current_date.strftime('%Y')}.csv"
    local_fname = download_from_aws(s3_fname)
    df = pd.read_csv(local_fname,index_col=0,parse_dates=True)
    
    # update percentile and write
    date_str = current_date.strftime('%Y-%m-%d') 
    df.loc[date_str] = round(average_percent)

    # write out updated station-id_year.csv
    df.to_csv(local_fname,index=True)
    upload_to_aws(local_fname, s3_fname)

    invoke_plotting_lambda(
        "createHeatmapPlot",
        {
            "obs_thisyear": df.reset_index().to_json(orient="records"),
            "station_id": station_id,
            "station_tz": tz,
            "station_label": this_station['label']})
    
    ##########################################

def local_testing():

    '''This function is for testing off AWS without boto3/s3. It is not used in the lambda function.'''

    import os
    oshome = os.environ['HOME']
    datapath = f'{oshome}/Downloads'

    # from latest-all.csv
    raw_event = '066214,Australia/Sydney,-33.8593,151.2048,25.7,2023-10-21 02:00:00+00:00,16.1,2023-10-20 19:40:00+00:00'.split(',')
    event = {
        "station_id": raw_event[0],
        "tz": raw_event[1],
        "lat": raw_event[2], 
        "lon": raw_event[3],
        "tmax_now": float(raw_event[4]),
        "tmax_dt": raw_event[5],
        "tmin_now": float(raw_event[6]),
        "tmin_dt": raw_event[7]
        }
    
    station_id, tz, lat, lon, tmax_now, tmax_dt, tmin_now, tmin_dt = event.values()
    
    local_fpath = f'{datapath}/locations.json'
    with open(local_fpath) as f:
        station_set = json.load(f)
    this_station = [s for s in station_set if s['id'] == station_id][0]
    
    # Get current date and time
    current_date_time = datetime.now(timezone(tz))
    current_date = current_date_time.date()
    
    # Calculate tavg from current tmax and tmin
    tavg_now = np.mean([tmax_now,tmin_now]).round()
    print(f"Updating station: {station_id}")
    print(f"Tavg.now = {tavg_now}")

    # Calculate percentiles of historical data
    # Read historical tmin obs from s3
    local_fpath = f'{datapath}/historical_{station_id}.txt'
    hist_obs = pd.read_csv(local_fpath,
                           na_values=["", " ", "NA"])
    hist_percentiles = calc_hist_percentiles(hist_obs)

    # Determine category of current temperature based on percentiles
    category_now = bin_obs(tavg_now, hist_percentiles)
    
    # Determine answer and comment based on category
    isit_answer, isit_comment = determine_answer_and_comment(category_now)
    
    # find where current temp falls in historical distribution
    ecdf = hist_obs['Tavg'].sort_values().dropna().searchsorted(tavg_now)/len(hist_obs['Tavg'].dropna())

    if tavg_now <= min(hist_obs['Tavg']):
        average_percent = 0.
    elif tavg_now > max(hist_obs['Tavg']):
        average_percent = 100.
    else:
        average_percent = 100 * np.round(ecdf, 3)
    
    # Save updated stats to file
    # Create stats dictionary
    stats_dict = {}
    stats_dict['isit_answer'] = isit_answer if isit_answer else None
    stats_dict['isit_comment'] = isit_comment if isit_comment else None
    stats_dict['isit_maximum'] = tmax_now if tmax_now else None
    stats_dict['isit_minimum'] = tmin_now if tmin_now else None
    stats_dict['isit_current'] = tavg_now if tavg_now else None
    stats_dict['isit_average'] = average_percent if average_percent else None
    stats_dict['isit_name'] = this_station['name'] if 'name' in this_station else None
    stats_dict['isit_label'] = this_station['label'] if 'label' in this_station else None
    if 'record_start' in this_station and 'record_end' in this_station:
        stats_dict['isit_span'] = f"{this_station['record_start']} - {this_station['record_end']}"
    else:
        stats_dict['isit_span'] = None
    
    file_path = f'/tmp/stats_{station_id}.json'