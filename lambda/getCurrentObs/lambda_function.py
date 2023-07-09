'''(c) isithotrightnow.com by Mat Lipson, Steefan Contractor and James Goldie (2023)

This function downloads ACORNSAT max/min temperatures in the historical record 
for dates within a (7-day) window and uploads this data to the isithot S3 bucket.
'''

import boto3
import pandas as pd
import datetime
import os

def lambda_handler(event, context):
    """
    Saves a DataFrame of historical Tmax, Tmin, and Tavg observations for the given date to s3 bucket.
    event Args:
        station_id (int): Station ID to retrieve data for.
        date (date, optional): Date to retrieve data for. Defaults to today's date.
        window (int, optional): Number of days to include in the historical window. Defaults to 7.
    Returns:
        pandas.DataFrame: writes pandas DataFrame containing historical Tmax, Tmin, and Tavg observations.
    """

    try: 
        station_id = event['station_id']
        print(f"processing {event['station_id']} historical")
    except KeyError:
        raise ValueError("Error: Station ID missing")
    try: 
        date = event['date']
    except KeyError:
        date = datetime.date.today()
        print(f"Warning: Date missing. Calculating percentiles for today's date: {date}")
    try:
        window = event['window']
    except KeyError:
        window = 7
        print(f"Warning: Window missing. Getting historical obs over +/- {window} day window")

    # Read historical tmax obs from s3
    s3_fpath = f"1-datasources/ACORN-SAT_V2.3.0/tmax.{station_id}.daily.csv"
    local_fpath = download_from_aws(s3_fpath)
    HistObs_Tmax = pd.read_csv(local_fpath,
                               header=None, skiprows=2,
                               usecols=[0, 1], names=["Date", "Tmax"],
                               na_values=["", " ", "NA"])
    # Read historical tmin obs from s3
    s3_fpath = f"1-datasources/ACORN-SAT_V2.3.0/tmin.{station_id}.daily.csv"
    local_fpath = download_from_aws(s3_fpath)
    HistObs_Tmin = pd.read_csv(local_fpath,
                               header=None, skiprows=2,
                               usecols=[0, 1], names=["Date", "Tmin"],
                               na_values=["", " ", "NA"])

    HistObs = pd.merge(HistObs_Tmax, HistObs_Tmin, on="Date", how="outer")

    # Filter by date window
    HistObs[["Year", "Month", "Day"]] = HistObs["Date"].str.split("-", expand=True).astype(int)
    HistObs["monthDay"] = pd.to_datetime(HistObs[["Year", "Month", "Day"]]).dt.strftime("%m%d")
    window_dates = [date + datetime.timedelta(days=x) for x in range(-window, window+1)]
    window_days = [x.strftime("%m%d") for x in window_dates]
    result = HistObs[HistObs["monthDay"].isin(window_days)].drop(columns=["monthDay"])

    # Calculate averages
    result["Tavg"] = (result["Tmax"] + result["Tmin"]) / 2)

    # Convert index to datetime
    result['Date'] = pd.to_datetime(result['Date'])
    result.set_index('Date', inplace=True)

    # upload to s3
    result.to_csv(f"/tmp/historical_{station_id}.txt")
    bucket_url = upload_to_aws(f"/tmp/historical_{station_id}.txt", f"2-processed/historical_{station_id}.txt")

    status = {
        'statusCode': 200,
        'body': ". Find this on the bucket at " + bucket_url
    }

    return status

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
        