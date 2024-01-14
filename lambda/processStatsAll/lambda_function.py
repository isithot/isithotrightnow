
import json
import boto3
import os

def lambda_handler(event, context):

    # Load station data from locations.json
    s3_fpath = f'1-datasources/locations.json'
    local_fpath = download_from_aws(s3_fpath)
    with open(local_fpath) as f:
        station_set = json.load(f)

    stats_all = {}
    for station in station_set:
        # load stat_sid.json
        s3_fpath = f"www/stats/stats_{station['id']}.json"
        local_fpath = download_from_aws(s3_fpath)
        if local_fpath is None:
            print(f'{s3_fpath} not found')
        else:
            with open(local_fpath) as f:
                stats_dict = json.load(f)
                # add locations.json addtional info
                stats_dict['isit_lat'] = station['lat']
                stats_dict['isit_lon'] = station['lon']
                stats_dict['isit_tz'] = station['tz']
                # add to stats_all
                stats_all[station['id']] = stats_dict

    # save stats_all
    local_fpath = f"/tmp/stats_all.json"
    with open(local_fpath, 'w') as f:
        json.dump(stats_all, f)

    # upload stats all to s3
    s3_fpath = f"www/stats/stats_all.json"
    upload_to_aws(local_fpath, s3_fpath)

    return

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