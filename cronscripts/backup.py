#!/usr/bin/python

# File: backup.py
# Author: m.lipson@unsw.edu.au
# Description: 
# This is a script run once a day to backup observations
# It is run through crontab, editable with:
# 	crontab -e

import os

path = '/srv/isithotrightnow'
path = '/Users/mjl/git/isithotrightnow'
# stations: [Sydney Obs, Melbourne, Brisbane] 
stations = ['IDN60901.94768','IDV60901.95936','IDQ60901.94576']

for statname in stations:
	os.system('cp %s/data/hist_%s.csv %s/databackup/hist_%s.backup'  %(path,statname,path,statname))