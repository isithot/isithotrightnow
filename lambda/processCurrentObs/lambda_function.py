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

# get_window_percentile: return the percentage of historical temps within the window (`window_temps`) that are lower than the current temperature (`temp_now`)
def get_window_percentile(window_temps, temp_now):
    ecdf = ECDF(window_temps)
    return 0. if temp_now <= min(window_temps) else 100. if temp_now > max(window_temps) else 100 * np.round(ecdf(temp_now), 3)

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

    # compare today's temperatures to the historical window temps
    maximum_percent = get_window_percentile(hist_obs['Tmax'], tmin_now)
    minimum_percent = get_window_percentile(hist_obs['Tmin'], tmax_now)
    average_percent = get_window_percentile(hist_obs['Tavg'], tavg_now)

    # create stats dictionary
    stats_dict = {}

    # add temperatures
    stats_dict['max_temp'] = tmax_now if tmax_now else None
    stats_dict['min_temp'] = tmin_now if tmin_now else None
    stats_dict['avg_temp'] = tavg_now if tavg_now else None

    # add percentiles
    stats_dict['max_pct'] = maximum_percent if maximum_percent else None
    stats_dict['min_pct'] = minimum_percent if minimum_percent else None
    stats_dict['avg_pct'] = average_percent if average_percent else None

    # add station metadata
    stats_dict['station_id'] = \
        this_station['id'] if 'id' in this_station else None
    stats_dict['station_name'] = \
        this_station['name'] if 'name' in this_station else None
    stats_dict['station_label'] = \
        this_station['label'] if 'label' in this_station else None
    if 'record_start' in this_station and 'record_end' in this_station:
        stats_dict['station_span'] = f"{this_station['record_start']} - {this_station['record_end']}"
    else:
        stats_dict['station_span'] = None

    # Convert dictionary to JSON string
    # stats_json = json.dumps(stats_dict)

    file_path = f'/tmp/stats_{station_id}.json'
    # Write the stats dictionary to the JSON file
    with open(file_path, "w") as f:
        json.dump(stats_dict, f)
    upload_to_aws(file_path, f'www/stats/stats_{station_id}.json')

    # set up payload base for plotting functions
    payload_base = {
        "station_id": station_id,
        "station_tz": tz,
        "station_label": this_station['label']
    }
    tavg_payload = {
        **payload_base,
        "temp_now": tavg_now,
        "indicator": "average",
        "hist_obs":
            hist_obs
                .drop(["Tmax", "Tmin"], axis = 1)
                .rename(columns = {"Tavg": "temp"})
                .to_json(orient="records"),
    }
    tmax_payload = {
        **payload_base,
        "temp_now": tmax_now,
        "indicator": "maximum",
        "hist_obs":
            hist_obs
                .drop(["Tavg", "Tmin"], axis = 1)
                .rename(columns = {"Tmax": "temp"})
                .to_json(orient="records"),
    }
    tmin_payload = {
        **payload_base,
        "temp_now": tmin_now,
        "indicator": "minimum",
        "hist_obs":
            hist_obs
                .drop(["Tmax", "Tavg"], axis = 1)
                .rename(columns = {"Tmin": "temp"})
                .to_json(orient = "records"),
    }
    
    # invoke time series plotting functions (for tmax, tmin, tavg separately)
    invoke_plotting_lambda("createTimeseriesPlot", tavg_payload)
    invoke_plotting_lambda("createTimeseriesPlot", tmax_payload)
    invoke_plotting_lambda("createTimeseriesPlot", tmin_payload)

    # invoke distribution plotting function (for tmax, tmin, tavg separately)
    invoke_plotting_lambda("createDistributionPlot", tavg_payload)
    invoke_plotting_lambda("createDistributionPlot", tmax_payload)
    invoke_plotting_lambda("createDistributionPlot", tmin_payload)

    # for the heatmap function, import other percentiles for the year to date

    # read and write yearly percentiles for heatmap (station-id_year.csv)
    s3_fname = f"2-processed/{station_id}-{current_date.strftime('%Y')}.csv"
    local_fname = download_from_aws(s3_fname)
    df = pd.read_csv(local_fname, index_col = 0, parse_dates = True)
    
    # update percentile and write
    date_str = current_date.strftime('%Y-%m-%d') 
    df.loc[date_str] = round(average_percent)

    # write out updated station-id_year.csv
    df.to_csv(local_fname, index = True)
    upload_to_aws(local_fname, s3_fname)

    invoke_plotting_lambda(
        "createHeatmapPlot",
        {
            **payload_base,
            "obs_thisyear": df.reset_index().to_json(orient = "records"),
        })
    
    # TODO - heatmap plots for tmax and tmin?
