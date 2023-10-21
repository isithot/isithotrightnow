'''(c) isithotrightnow.com by Mat Lipson, Steefan Contractor and James Goldie (2023)

This function copies s3 data to backup once per day.
'''

import boto3
import time
import os

def lambda_handler(event, context):
    
    # Create an AWS Lambda client
    client = boto3.client('lambda')
    
    today = time.strftime("%Y-%m-%d")
    
    s3_fpath = f"1-datasources/latest/latest-all.csv"
    local_fpath = download_from_aws(s3_fpath)
    
    new_s3_fpath = f"4-backups/{today}-all.csv"
    upload_to_aws(local_fpath, new_s3_fpath)
    
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
    

