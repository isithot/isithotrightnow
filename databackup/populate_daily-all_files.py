'''this script populates databackup/[date]-all.csv type files in the form:
014015,Australia/Darwin,-12.4239,130.8925,32.5,2019-04-10T05:44:00Z,25.3,2019-04-09T21:37:00Z
015590,Australia/Darwin,-23.7951,133.8890,32.8,2019-04-10T05:43:00Z,20.2,2019-04-09T21:24:00Z
066062,Australia/Sydney,-33.8607,151.2050,21.3,2019-04-10T05:20:00Z,13.6,2019-04-09T20:01:00Z
070351,Australia/Sydney,-35.3088,149.2004,18.5,2019-04-10T06:15:00Z,0.5,2019-04-09T20:13:00Z
067105,Australia/Sydney,-33.6004,150.7761,21.4,2019-04-10T01:38:00Z,11.2,2019-04-09T17:56:00Z
040842,Australia/Brisbane,-27.3917,153.1292,26.4,2019-04-10T02:10:00Z,17.4,2019-04-09T17:40:00Z
023090,Australia/Adelaide,-34.9211,138.6216,19.5,2019-04-10T06:15:00Z,12.2,2019-04-09T18:09:00Z
094029,Australia/Hobart,-42.8897,147.3278,18.3,2019-04-10T03:23:00Z,7.1,2019-04-09T20:45:00Z
087031,Australia/Melbourne,-37.8565,144.7566,17.4,2019-04-10T02:34:00Z,13.9,2019-04-10T09:50:00Z
009021,Australia/Perth,-31.9275,115.9764,28.2,2019-04-10T07:02:00Z,11.7,2019-04-09T23:01:00Z

only need to change year and month numbers required
'''

import numpy as np
import pandas as pd
import io
import requests

pd.set_option('display.width', 150)

siteinfo = pd.DataFrame( columns=('sid','name','url_id','csv_str'),
    data = [
    ['014015','Darwin Airport',           'IDCJDW8014','Australia/Darwin,-12.4239,130.8925'],
    ['015590','Alice Springs Airport',    'IDCJDW8002','Australia/Darwin,-23.7951,133.8890'],
    ['066214','Sydney (Observatory Hill)','IDCJDW2124','Australia/Sydney,-33.8593,149.2004'],
    ['070351','Canberra Airport',         'IDCJDW2801','Australia/Sydney,-35.3088,149.2004'],
    ['067105','Richmond RAAF',            'IDCJDW2119','Australia/Sydney,-33.6004,150.7761'],
    ['048245','Bourke',                   'IDCJDW2016','Australia/Sydney,-30.0362,145.9521'],
    ['040842','Brisbane Aero',            'IDCJDW4020','Australia/Brisbane,-27.3917,153.1292'],
    ['031011','Cairns Aero',              'IDCJDW4024','Australia/Brisbane,-16.8736,145.7458'],
    ['023000','Adelaide',                 'IDCJDW5081','Australia/Adelaide,-34.9257,138.5832'],
    ['094029','Hobart (Ellerslie Rd)',    'IDCJDW7021','Australia/Hobart,-42.8897,147.3278'],
    ['086338','Melbourne (Olympic Park)', 'IDCJDW3033','Australia/Melbourne,-37.8255,144.9816'],
    ['087031','Laverton RAAF',            'IDCJDW3043','Australia/Melbourne,-37.8565,144.7566'],
    ['009021','Perth Airport',            'IDCJDW6110','Australia/Perth,-31.9275,115.9764'],
    ])

siteinfo = siteinfo.set_index('sid')


###### CHANGE YEAR AND MONTHS ####
year = '2023'
update_sids = ['066214']

for month in [1]:
    ##############################

    month_str = str(month).zfill(2)

    # download monthly data
    data = {}
    for sid in update_sids:
        print('getting %s: %s csv from BOM' %(sid,siteinfo.loc[sid,"name"]))

        print('NOW MUST MANUALLY DOWNLOAD FROM:')
        url = 'http://www.bom.gov.au/climate/dwo/%s%s/text/%s.%s%s.csv' %(year,month_str,siteinfo.loc[sid,"url_id"],year,month_str)
        print(url)

        fname = url.split('/')[-1]
        fpath = f'./2022/{fname}'

        # open csv, but skip unknown lenght of rows that aren't valid
        with open(fpath, encoding="utf8", errors='ignore') as f:
            while f.readline() != '\n':
                pass

            data[sid]=pd.read_csv(f,usecols =[1,2,3],names=['day','tmin','tmax'],skiprows=1,parse_dates=[0],dayfirst=True,index_col=[0])

    # create daily '-all.csv' file
    key = next(iter(data))
    for date in data[key].index:

        day_str   = str(date.day).zfill(2)

        fname = '%s%s%s-all.csv' %(year[-2:],month_str,day_str)
        with open(fname, 'w') as f:

            f.write('station_id,tz,lat,lon,tmax,tmax_dt,tmin,tmin_dt\n')
            for key,item in data.items():
                f.write("%s,%s,%s,%sT06:00:00Z,%s,%sT18:00:00Z\n" %(key,siteinfo.loc[key,'csv_str'],item.loc[date,'tmax'],date.date(),item.loc[date,'tmin'],date.date()))

    print('done month %s' %month)

############################################################
### TO UPDATE SELECT LINES ONLY BASED ON update_sids
# shutil.move(source, source + "~")
# with open(source+'~', 'r') as f0:
#     with open(source, 'w') as f:
#         for line in f0:
#             for sid in update_sids:
#                 if sid in line:
#                     print(sid,line)
#                     f.write("%s,%s,%s,%sT06:00:00Z,%s,%sT18:00:00Z\n" %(key,siteinfo.loc[key,'csv_str'],item.loc[date,'tmax'],date.date(),item.loc[date,'tmin'],date.date()))
#                 else:
#                     f.write(line)

############################################################

# #### FOLLOWING STOPPED WORKING IN 2022 BECAUSE BOM DISALLOWED SCRAPING

# ###### CHANGE YEAR AND MONTHS ####
# year = '2022'
# for month in [1]:
#     ##############################

#     month_str = str(month).zfill(2)

#     # download monthly data
#     data = {}
#     for sid in siteinfo.index:
#         print('getting %s: %s csv from BOM' %(sid,siteinfo.loc[sid,"name"]))
#         try:
#             url = 'http://www.bom.gov.au/climate/dwo/%s%s/text/%s.%s%s.csv' %(year,month_str,siteinfo.loc[sid,"url_id"],year,month_str)
#             # get csv
#             s=requests.get(url).text
#             # remove header junk
#             s = s.partition('Date')[1]+s.partition('Date')[2] 
#             # import to dataframe
#             data[sid]=pd.read_csv(io.StringIO(s),header=None,usecols =[1,2,3],skiprows=1,names=['day','tmin','tmax'],parse_dates=[0],dayfirst=True,index_col=[0])
#         except Exception as e:
#             print(e)

#     # create daily '-all.csv' file
#     key = next(iter(data))
#     for date in data[key].index:

#         day_str   = str(date.day).zfill(2)

#         fname = '%s%s%s-all.csv' %(year[-2:],month_str,day_str)
#         with open(fname, 'w') as f:
#             f.write('station_id,tz,lat,lon,tmax,tmax_dt,tmin,tmin_dt\n')
#             for key,item in data.items():
#                 f.write("%s,%s,%s,%sT06:00:00Z,%s,%sT18:00:00Z\n" %(key,siteinfo.loc[key,'csv_str'],item.loc[date,'tmax'],date.date(),item.loc[date,'tmin'],date.date()))

#     print('done month %s' %month)


