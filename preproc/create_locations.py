# imports csv and creates locations.json

import json
import csv
import os
from timezonefinder import TimezoneFinder

oshome = os.getenv('HOME')
wdir = f'{oshome}/git/isithotrightnow/preproc'

json_file = f'{wdir}/locations.json'
csv_file = f'{wdir}/station_list_v2p5.csv'
fallback_file = f'{wdir}/fallback_ids.json'

dummy_data = {
    "id": "066214",
    "name": "Sydney (Observatory Hill)",
    "label": "Sydney City",
    "lat": "-33.8593",
    "lon": "151.2048",
    "tz": "Australia/Sydney",
    "record_start": "1910",
    "record_end": "2022"
  }

def convert_csv_to_json(csv_file, json_file):
    locations = []
    with open(csv_file, mode='r', encoding='utf-8-sig') as file:
        csv_reader = csv.DictReader(file)

        for row in csv_reader:
            location = {
                "id": row["Number"].strip().zfill(6),
                "name": row["Station name"].strip(),
                "label": row["Station name"].strip(),
                "lat": row["Latitude"].strip(),
                "lon": row["Longitude"].strip(),
                "tz": "Australia/Sydney",  # Default timezone, can be modified later
                "record_start": row["Start"].strip(),
                "record_end": "2023"  # end for v2.5 is 2023
            }

            # update some custom labels based on id
            if location['name'] == 'Sydney (Observatory Hill)':
                location['label'] = 'Sydney City'
            elif location['name'] == 'Richmond (NSW)':
                location['label'] = 'Sydney West (Richmond)'
            elif location['name'] == 'Richmond (Qld)':
                location['label'] = 'Richmond (Qld)'
            elif location['name'] == 'Melbourne (Olympic Park)':
                location['label'] = 'Melbourne City'
            elif location['name'] == 'Melbourne (Laverton)':
                location['label'] = 'Melbourne West (Laverton)'
            elif location['name'] == 'Canberra Airport':
                location['label'] = 'Canberra'
            elif location['name'] == 'Hobart (Ellerslie Rd)':
                location['label'] = 'Hobart'
            elif location['name'] == 'Brisbane Aero':
                location['label'] = 'Brisbane'
            elif location['name'] == 'Alice Springs Airport':
                location['label'] = 'Alice Springs'
            elif location['name'] == 'Darwin Airport':
                location['label'] = 'Darwin'
            elif location['name'] == 'Adelaide (West Terrace/Ngayirdapira)':
                location['label'] = 'Adelaide'
            elif location['name'] == 'Perth Airport':
                location['label'] = 'Perth'
            elif location['name'] == 'Launceston Airport':
                location['label'] = 'Launceston'
            # else if Airport in name, remove from label and strip trailing whitespace
            elif 'Airport' in location['name']:
                location['label'] = location['name'].replace(' Airport', '').strip()
            # else if bracket in name, remove from label and strip trailing whitespace
            elif '(' in location['name'] and ')' in location['name']:
                location['label'] = location['name'].split('(')[0].strip()

            locations.append(location)

            # assert no double names or labels
            assert len([loc for loc in locations if loc['name'] == location['name']]) == 1, f"Duplicate name found: {location['name']}"
            assert len([loc for loc in locations if loc['label'] == location['label']]) == 1, f"Duplicate label found: {location['label']}"

    return locations

def update_tz_from_lat_lon(locations):
    """
    Updates the 'tz' field in each location dict based on its latitude and longitude.
    """
    tf = TimezoneFinder()
    for loc in locations:
        try:
            lat = float(loc['lat'])
            lon = float(loc['lon'])
            tz = tf.timezone_at(lat=lat, lng=lon)
            if tz:
                loc['tz'] = tz
        except Exception as e:
            # If conversion or lookup fails, keep the existing tz
            pass
    return locations

def apply_fallback_ids(locations, fallback_file):
    """
    Merges in a station's "fallback_ids" - the ordered list of alternate
    bom-ids getLatestObs should try scraping when a station's own bom-id is
    missing from BOM's live feed - from a hand-maintained file, rather than
    from station_list_v2p5.csv. That CSV gets wholesale replaced whenever
    ACORN-SAT is updated, which would otherwise silently wipe any fallbacks
    recorded directly on the generated locations.json.
    """
    if not os.path.exists(fallback_file):
        return locations

    with open(fallback_file, encoding='utf-8') as f:
        fallback_map = json.load(f)

    for location in locations:
        if location['id'] in fallback_map:
            location['fallback_ids'] = fallback_map[location['id']]

    return locations

if __name__ == "__main__":
    locations = convert_csv_to_json(csv_file, json_file)
    locations = apply_fallback_ids(locations, fallback_file)
    with open(json_file, 'w', encoding='utf-8') as jsonf:
        json.dump(locations, jsonf, indent=4)
    print(f"Data has been written to {json_file}")


