# this script populates databackup/[date]-all.csv type files
# as we missed some at the start of 2018

import numpy as np
import pandas as pd

pd.set_option('display.width', 150)

year = '2018'
month = '10'
sday = 1
eday = 27


# read in csv of site monthtly data from eg. http://www.bom.gov.au/climate/dwo/IDCJDW4020.latest.shtml, then click on 'plain text version'.
# canberra = pd.read_csv('IDCJDW2801.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=8,names=['day','tmin','tmax'])
alice  = pd.read_csv('IDCJDW8002.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=8,names=['day','tmin','tmax'])
darwin = pd.read_csv('IDCJDW8014.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=6,names=['day','tmin','tmax'])
richmond = pd.read_csv('IDCJDW2119.%s%s.csv' %(year,month),header=None,usecols =[1,2,3],skiprows=9,names=['day','tmin','tmax'])

# old formats
# darwin 		= pd.read_csv('Darwin_014015.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# alice 		= pd.read_csv('Alice_015590.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# sydney 		= pd.read_csv('Sydney_066062.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# richmond 	= pd.read_csv('Richmond_067105.csv',header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# brisbane 	= pd.read_csv('Brisbane_040842.csv',header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# adelaide 	= pd.read_csv('Adelaide_023090.csv',header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# hobart 		= pd.read_csv('Hobart_094029.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# melbourne 	= pd.read_csv('Melbourne_087031.csv',header=None,usecols=[0,2,3],names=['day','tmin','tmax'])
# perth 		= pd.read_csv('Perth_009021.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
# sites = [darwin,alice,sydney,canberra,richmond,brisbane,adelaide,hobart,melbourne,perth]

# list site (name,ID) tupple
# sites = [(canberra,70351)]
sites = [(alice,'015590'),(darwin,'014015'),(richmond,'067105')]

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
		newtemplate.loc[newtemplate.station_id==site[1],'tmax_dt'] = '2018-%s-%sT00:00:00Z' %(month,str(day).zfill(2))
		newtemplate.loc[newtemplate.station_id==site[1],'tmin_dt'] = '2018-%s-%sT00:00:00Z' %(month,str(day).zfill(2))
	# for each day, save to csv
	newtemplate.to_csv('18%s%s-all.csv' %(month,str(day).zfill(2)),index=False)
