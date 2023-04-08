import pandas as pd
from datetime import date, timedelta

def lambda_handler(station_id, date=date.today(), window=7):
    """
    Returns a DataFrame of historical Tmax, Tmin, and Tavg observations for the given date.

    Args:
        station_id (int): Station ID to retrieve data for.
        date (date, optional): Date to retrieve data for. Defaults to today's date.
        window (int, optional): Number of days to include in the historical window. Defaults to 7.

    Returns:
        pandas.DataFrame: DataFrame containing historical Tmax, Tmin, and Tavg observations.
    """
    # Raise an error if station ID is missing.
    if station_id is None:
        raise ValueError("Error: Station ID missing")

    # Raise a warning if date or window is missing.
    if date is None:
        print("Warning: Date missing. Calculating percentiles for today's date")
    if window is None:
        print("Warning: Window missing. Getting historical obs over +/- 7 day window")

    # Read historical obs
    HistObs_Tmax = pd.read_csv(f"{fullpath}/data/ACORN-SAT_V2.3.0/tmax.{station_id}.daily.csv",
                               header=None, skiprows=2,
                               usecols=[0, 1], names=["Date", "Tmax"],
                               na_values=["", " ", "NA"])
    HistObs_Tmin = pd.read_csv(f"{fullpath}/data/ACORN-SAT_V2.3.0/tmin.{station_id}.daily.csv",
                               header=None, skiprows=2,
                               usecols=[0, 1], names=["Date", "Tmin"],
                               na_values=["", " ", "NA"])

    HistObs = pd.merge(HistObs_Tmax, HistObs_Tmin, on="Date", how="outer")
    HistObs[["Year", "Month", "Day"]] = HistObs["Date"].str.split("-", expand=True).astype(int)

    # Calculate averages
    HistObs["Tavg"] = (HistObs["Tmax"] + HistObs["Tmin"]) / 2
    HistObs["monthDay"] = pd.to_datetime(HistObs[["Year", "Month", "Day"]]).dt.strftime("%m%d")

    # Filter by date window
    window_dates = [date + timedelta(days=x) for x in range(-window, window+1)]
    result = HistObs[HistObs["monthDay"].isin(window_dates)].drop(columns=["monthDay"])

    result.to_csv("/tmp/historical.txt")

    bucket_url = upload_to_aws("/tmp/historical.txt", "sandbox/historical.txt")

    result = {
        'statusCode': 200,
        'body': json.dumps(str(num1) + " + " + str(num2) + " = " + str(result) + ". Find this on the bucket at " + bucket_url)
    }

    return result

def upload_to_aws(local_file, s3_file):
    s3 = boto3.client('s3')

    try:
        s3.upload_file(local_file, "isithot-data", s3_file)
        url = s3.generate_presigned_url(
            ClientMethod='get_object',
            Params={
                'Bucket': "isithot-data",
                'Key': s3_file
            },
            ExpiresIn=24 * 3600
        )

        print("Upload Successful", url)
        return url
    except FileNotFoundError:
        print("The file was not found")
        return None