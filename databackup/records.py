# this script populates databackup/[date]-all.csv type files
# as we missed some at the start of 2018

import numpy as np
import pandas as pd

pd.set_option('display.width', 150)

# read in csv of site monthtly data from eg. http://www.bom.gov.au/climate/dwo/IDCJDW4020.latest.shtml
darwin 		= pd.read_csv('Darwin_014015.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
alice 		= pd.read_csv('Alice_015590.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
sydney 		= pd.read_csv('Sydney_066062.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
canberra 	= pd.read_csv('Canberra_070351.csv',header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
richmond 	= pd.read_csv('Richmond_067105.csv',header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
brisbane 	= pd.read_csv('Brisbane_040842.csv',header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
adelaide 	= pd.read_csv('Adelaide_023090.csv',header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
hobart 		= pd.read_csv('Hobart_094029.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])
melbourne 	= pd.read_csv('Melbourne_087031.csv',header=None,usecols=[0,2,3],names=['day','tmin','tmax'])
perth 		= pd.read_csv('Perth_009021.csv',	header=None,usecols =[0,2,3],names=['day','tmin','tmax'])

sites = [darwin,alice,sydney,canberra,richmond,brisbane,adelaide,hobart,melbourne,perth]
dates = list(range(1,17))

template = pd.read_csv('180120-all.csv')

# for each day in month, loop through each site to replace values in template frame with csv values
for idate,date in enumerate(dates):
	frame = template.copy()
	for isite,site in enumerate(sites):
		frame.loc[isite,'tmax']    = site.loc[idate,'tmax']
		frame.loc[isite,'tmin']    = site.loc[idate,'tmin']
		frame.loc[isite,'tmax_dt'] = '2018-01-%sT00:00:00Z' %str(date).zfill(2)
		frame.loc[isite,'tmin_dt'] = '2018-01-%sT00:00:00Z' %str(date).zfill(2)
	# for each day, save to csv
	frame.to_csv('1801%s-all.csv' %(str(date).zfill(2)),index=False)
