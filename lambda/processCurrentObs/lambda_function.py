import pandas as pd
import numpy as np
import json
import boto3

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
    return pd.cut(
        Tavg_now,
        bins=[
            -100,
            *hist_percentiles.loc[hist_percentiles.index != "50%", "Tavg"],
            100
        ],
        labels=["bc", "rc", "c", "a", "h", "rh", "bh"],
        include_lowest=True,
        right=False
        ).astype(str)
        # The -100 and 100 allow us to have the lowest and highest bins

def ECDF(data):
    """Compute ECDF for a one-dimensional array of measurements."""
    # Sort the data in ascending order
    sorted_data = np.sort(data)
    
    # Calculate the y-values for the ECDF
    n = len(data)
    y_values = np.arange(1, n+1) / n
    
    # Define the ECDF function
    def ecdf_function(x):
        """Return the value of the ECDF for a given x."""
        # Find the index of the first element in the sorted data greater than or equal to x
        index = np.searchsorted(sorted_data, x, side='right')
        
        # Return the y-value for that index
        return y_values[index]
    
    # Return the ECDF function
    return ecdf_function


def tavg_hist_percentile(hist_tavg, tavg_now):
    ecdf = ECDF(hist_tavg)
    return 100 * np.round(ecdf(tavg_now), 2)

def lambda_handler(event, context):
    # Load station data from locations.json
    loc_s3_fpath = f'sandbox/locations.json'
    loc_local_fpath = download_from_aws(loc_s3_fpath)
    with open(loc_local_fpath) as f:
        station_set = json.load(f)

    # Loop over each station in station_set
    for this_station in station_set:
        print(f"\n\nBeginning analysis: {this_station['label']}")

        # Create directory for output files
        output_dir = f"output/{this_station['id']}"
        os.makedirs(output_dir, exist_ok=True)

        # Get current date and time
        current_date_time = datetime.now(timezone(this_station['tz']))
        current_date = current_date_time.date()

        # Get current max and min temperatures for this_station
        obs_filename = 'data/latest/latest-all.csv'
        curr_obs_df = get_current_obs(this_station['id'], obs_filename)
        tmax_now = curr_obs_df['tmax'].values[0]
        tmin_now = curr_obs_df['tmin'].values[0]
        tavg_now = (tmax_now + tmin_now) / 2.0
        print(f"Updating station: {this_station['label']}")
        print(f"Tavg.now = {tavg_now}")
        
        # Calculate percentiles of historical data
        # Read historical tmin obs from s3
        s3_fpath = f"sandbox/historical_{station_id}.txt"
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

        file_path = f'/tmp/stats_{stationid}.json'
        # Write the stats dictionary to the JSON file
        with open(file_path, "w") as f:
            json.dump(stats_dict, f)
        upload_to_aws(file_path, f'sandbox/stats_{stationid}.json')