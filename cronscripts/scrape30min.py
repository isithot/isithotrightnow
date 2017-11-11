#!/usr/bin/python

# File: scrape30min.py
# Author: m.lipson@unsw.edu.au
# Description: 
# This is a script run every half hour to scrape current observations
# It is run through crontab, editable with:
# 	crontab -e

import os
import urllib

path = '/srv/isithotrightnow'
# path = '/Users/mjl/git/isithotrightnow'

# stations: [Sydney Obs, Melbourne, Brisbane] 
stations = ['IDN60901.94768','IDV60901.95936','IDQ60901.94576']

# retrieve latest observations from BOM and append to historical file for each station
for statname in stations:
	urllib.urlretrieve('http://www.bom.gov.au/fwo/%s/%s.axf' %(statname.split('.')[0],statname), '%s/data/%s.axf' %(path,statname))
	os.system("grep -o '^0,.*' %s/data/%s.axf >> %s/data/hist_%s.csv" %(path,statname,path,statname))
