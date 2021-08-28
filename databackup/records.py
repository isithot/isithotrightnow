# this script populates databackup/[date]-all.csv type files
# as we missed some at the start of 2018

import numpy as np
import pandas as pd

pd.set_option('display.width', 150)

year = '2019'
month = '01'
sday = 1
eday = 2

# read in csv of site monthtly data from eg. http://www.bom.gov.au/climate/dwo/IDCJDW4020.latest.shtml, then click on 'plain text version'.
# canberra = pd.read_csv('IDCJDW2801.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=8,names=['day','tmin','tmax'])
alice  = pd.read_csv('IDCJDW8002.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=8,names=['day','tmin','tmax'])
s_alice = (alice,'015590')
# darwin = pd.read_csv('IDCJDW8014.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=6,names=['day','tmin','tmax'])
# s_darwin = (darwin,'014015')
# richmond = pd.read_csv('IDCJDW2119.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=9,names=['day','tmin','tmax'])
# s_richmond = (richmond,'067105')
adelaide = pd.read_csv('IDCJDW5002.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=8,names=['day','tmin','tmax'])
s_adelaide = (adelaide,'023090')
laverton = pd.read_csv('IDCJDW3043.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=7,names=['day','tmin','tmax'])
s_laverton = (laverton,'087031')




# list site (name,ID) tupple
# sites = [(canberra,70351)]
sites = [s_alice,s_adelaide,s_laverton]

# for each day in month, loop through each site to replace values in template frame with csv values
for day in range(sday,eday+1):
	# read template file for month and day (for replacing some stations, retaining other data)
	template = pd.read_csv('18%s%s-all.csv' %(month,str(day).zfill(2)),dtype={'station_id':str})
	newtemplate = template.copy()
	for isite,site in enumerate(sites):
		newtmax = site[0].loc[site[0].day=='2018-%s-%s' %(month,day),'tmax'].values[0]
		newtmin = site[0].loc[site[0].day=='2018-%s-%s' %(month,day),'tmin'].values[0]
		newtemplate.loc[newtemplate.station_id==site[1],'tmax']    = newtmax
		newtemplate.loc[newtemplate.station_id==site[1],'tmin']    = newtmin
		newtemplate.loc[newtemplate.station_id==site[1],'tmax_dt'] = '2018-%s-%sT06:00:00Z' %(month,str(day).zfill(2))
		newtemplate.loc[newtemplate.station_id==site[1],'tmin_dt'] = '2018-%s-%sT18:00:00Z' %(month,str(day-1).zfill(2))
	# for each day, save to csv
	newtemplate.to_csv('18%s%s-all.csv' %(month,str(day).zfill(2)),index=False)
