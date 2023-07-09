import json
import boto3
import os

def lambda_handler(event, context):
    print(">>> Does 1-datasources/locations.json exist? " +
        str(check_if_file_exists("1-datasources/locations.json")))
    
    
    print(">>> Does 1-datasources/blah.csv exist? " +
        str(check_if_file_exists("1-datasources/blah.csv")))
    
    return {
        'statusCode': 200,
        'body': json.dumps('>>> All done!')
    }

# check_if_file_exists: returns True if the specified path (or path prefix)
# matches an existing file on the s3 bucket, or False if no file exists
def check_if_file_exists(path):
    s3 = boto3.client("s3")
    bucket_name = "isithot-data"
    
    try:
        # search for the file. if the response has a Contents field, it exists
        response = s3.list_objects_v2(Bucket = bucket_name, Prefix = path)
        return "Contents" in response.keys()

    except Exception as e:
        print(f"Error checking for path {path}: {e}")
        return None

def download_from_aws(s3_fpath):

    s3 = boto3.client("s3")
    bucket_name = "isithot-data"

    fname = os.path.basename(s3_fpath)
    local_file_path = f"/tmp/{fname}"

    try:
        # Get the object from S3 bucket
        response = s3.get_object(Bucket=bucket_name, Key=s3_fpath)

        # Save the object to local file
        with open(local_file_path, "wb") as f:
            f.write(response["Body"].read())

        print(f"File saved to {local_file_path}")

        return local_file_path

    except Exception as e:
        print(f"Error getting S3 object: {e}")
        return None

def upload_to_aws(local_file, s3_file):

    s3 = boto3.client("s3")
    bucket_name = "isithot-data"

    try:
        s3.upload_file(local_file, bucket_name, s3_file)
        url = s3.generate_presigned_url(
            ClientMethod = "get_object",
            Params={
                "Bucket": bucket_name,
                "Key": s3_file
            },
            ExpiresIn = 24 * 3600
        )

        print("Upload Successful", url)
        return url
    except FileNotFoundError:
        print("The file was not found")
        return None
