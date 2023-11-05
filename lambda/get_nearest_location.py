import json

def lambda_handler(event, context):

    '''
    This function returns the nearest isithot location to the client lat and lon
    The input 'event' is the ip-api.com call, such as:
    http://ip-api.com/json/24.48.0.1?fields=status,country,lat,lon
    
    which returns:
        {"status": "success","country": "Canada","lat": 45.4998,"lon": -73.6087}

    additional fields can be added, or all fields can be returned by removing the ?fields=... part
    see: https://ip-api.com/docs/api:json

    ip-api allow 45 requests per minute

    Returns:
        url (str): the url suffix of the closest isithot location
    '''

    # local load locations.json
    # with open('locations.json') as f:
    #     locations = json.load(f)

    # Load station data from locations.json
    s3_fpath = f'1-datasources/locations.json'
    local_fpath = download_from_aws(s3_fpath)
    with open(local_fpath) as f:
        locations = json.load(f)
    
    try:
        # find which location is closest to client lat and lon
        closest_distance = 1E6    # init
        for location in locations:
            distance = (float(event['lat']) - float(location['lat']))**2 + (float(event['lon']) - float(location['lon']))**2
            if distance < closest_distance:
                closest_distance = distance
                closest_location = location
    except Exception:
        print('location not found, defaulting to first location')
        closest_location = locations[0]
    
    return closest_location['url']

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
    
def test():

    # test
    event = {}
    event['status'] = 'success'
    event['lat'] = 45.4998
    event['lon' ]= -73.6087
    
    lambda_handler(event, None)