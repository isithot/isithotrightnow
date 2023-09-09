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


def ECDF(data):
    """Compute ECDF for a one-dimensional array of measurements."""
    # Drop NAs and sort the data in ascending order
    sorted_data = np.sort(data.dropna())

    # Calculate the y-values for the ECDF
    n = len(data)
    y_values = np.arange(1,n+1) / n

    # Define the ECDF function
    def ecdf_function(x):
        """Return the value of the ECDF for a given x."""
        # Find the index of the first element in the sorted data greater than or equal to x
        index = np.searchsorted(sorted_data, x, side='left')

        # Return the y-value for that index
        return y_values[index-1]

    # Return the ECDF function
    return ecdf_function


def tavg_hist_percentile(hist_tavg, tavg_now):
    ecdf = ECDF(hist_tavg)
    return 0. if tavg_now <= min(hist_tavg) else 100. if tavg_now > max(hist_tavg) else 100 * np.round(ecdf(tavg_now), 3)

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

    # Load station metadata from locations.json
    loc_s3_fpath = f'1-datasources/locations.json'
    loc_local_fpath = download_from_aws(loc_s3_fpath)
    with open(loc_local_fpath) as f:
        station_set = json.load(f)
    this_station = [s for s in station_set if s['id'] == station_id][0]

    # Create directory for output files
    # output_dir = f"output/{station_id}"
    # os.makedirs(output_dir, exist_ok=True)

    # Get current date and time
    current_date_time = datetime.now(timezone(tz))
    current_date = current_date_time.date()

    # Calculate tavg from current tmax and tmin
    tavg_now = (tmax_now + tmin_now) / 2.0
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

    # Calculate percentage of historical data that is lower than current temperature
    average_percent = tavg_hist_percentile(hist_obs['Tavg'], tavg_now)

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

    # Convert dictionary to JSON string
    stats_json = json.dumps(stats_dict)

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
    
    # invoke heatwave plotting function
    # TODO - do we have obs_thisyear here? (prev. databackup/[id]-[year].csv)
    # invoke_plotting_lambda(
    #     "createHeatwavePlot",
    #     json.dumps({
    #         "obs_thisyear": # ...,
    #         "station_id": station_id,
    #         "station_tz": tz,
    #         "station_label": this_station['label']}))
