# %%
from ftplib import FTP
import pandas as pd
import json
import tarfile
import glob

def get_latest_acornsat_filenames():
    with FTP("ftp.bom.gov.au") as ftp:
        ftp.login()
        ftp.cwd("anon/home/ncc/www/change/ACORN_SAT_daily")
        files = pd.DataFrame(ftp.nlst(), columns=["Name"])
    files = files[files.Name.str.contains("acorn_sat_v.*_daily_t.{3}\.tar\.gz")]
    files['Version'] = files['Name'].str.extract('acorn_sat_(.*)_daily_t.{3}\.tar\.gz')
    latest_version = files.sort_values('Version').Version.iloc[-1]
    latest_tmax_file = files[files.Name.str.contains("tmax")].sort_values('Version').Name.iloc[-1]
    latest_tmin_file = files[files.Name.str.contains("tmin")].sort_values('Version').Name.iloc[-1]
    return latest_tmax_file, latest_tmin_file, latest_version

def untar_file(file_path):
    with tarfile.open(file_path, 'r:gz') as tar:
        tar.extractall()

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

def lambda_handler(event, context):
    latest_tmax_file, latest_tmin_file, latest_version = get_latest_acornsat_filenames()
    # download current version file from S3
    download_from_aws('1-datasource/ACORN-SAT_version.json')
    with open('ACORN-SAT_version.json', 'r') as f:
        data = json.load(f)
        current_version = data['version']
    if latest_version > current_version:
        with FTP("ftp.bom.gov.au") as ftp:
            ftp.login()
            ftp.cwd("anon/home/ncc/www/change/ACORN_SAT_daily")
            files = pd.DataFrame(ftp.nlst(), columns=["Name"])
            with open(latest_tmax_file,"wb") as ftmax:
                ftp.retrbinary(f"RETR {latest_tmax_file}", ftmax.write)
            with open(latest_tmin_file,"wb") as ftmin:
                ftp.retrbinary(f"RETR {latest_tmin_file}", ftmin.write)

        with open('ACORN-SAT_version.json', 'w') as f:
            json.dump({'version': latest_version}, f)

        # upload latest_ACORN-SAT_version.json to s3
        upload_to_aws('ACORN-SAT_version.json', '1-datasources/ACORN-SAT_version.json')

        # upload latest_tmax_file to s3
        # untar latest_tmax_file
        untar_file(latest_tmax_file)
        tmax_files = pd.DataFrame(glob.glob('tmax.??????.daily.csv'), columns=["Name"])
        # upload tmax_files to s3
        for file in tmax_files.Name:
            upload_to_aws(file, f'1-datasources/ACORN-SAT_V{latest_version}/' + file)

        # upload latest_tmin_file to s3
        # untar latest_tmin_file
        untar_file(latest_tmin_file)
        tmin_files = pd.DataFrame(glob.glob('tmin.??????.daily.csv'), columns=["Name"])
        # upload tmin_files to s3
        for file in tmin_files.Name:
            upload_to_aws(file, f'1-datasources/ACORN-SAT_V{latest_version}/' + file
