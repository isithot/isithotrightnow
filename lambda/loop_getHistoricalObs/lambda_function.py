'''(c) isithotrightnow.com by Mat Lipson, Steefan Contractor and James Goldie (2023)

This is the main loop which calls other lambda functions.
'''

import boto3
import os
import json
import datetime

def lambda_handler(event, context):
    # Create an AWS Lambda client
    client = boto3.client('lambda')

    # read in the locations.json file from s3
    s3_fpath = f"1-datasources/locations.json"
    local_fpath = download_from_aws(s3_fpath)

    # Open the JSON file
    with open(local_fpath) as file:
        locations = json.load(file)

    # define date for calculating historical period
    date = datetime.date.today() + datetime.timedelta(days=1)
    date_str = date.strftime('%Y-%m-%d')
    print(f'date for historical period: {date}')

    # loop through locations and invoke the GetHistoricalObs lambda function
    for i,location in enumerate(locations):
        station_id = location['id']
        station_name = location['name']
        
        print(f'invoking {station_id}: {station_name}')

        # Construct the parameters for the Lambda function invocation
        params = {
            'FunctionName': 'GetHistoricalObs',
            'InvocationType': 'Event',
            'Payload': '{"station_id": "%s", "date" : "%s", "window" : 7}' %(station_id,date_str)
        }
        
        print(params)

        try:
            # Invoke Function B
            response = client.invoke(**params)
            print(response)
            # Handle the response from Function B
        except Exception as e:
            print(e)
            # Handle any errors that occurred during the invocation

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