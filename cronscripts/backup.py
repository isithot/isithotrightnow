#!/usr/bin/python

# File: backup.py
# Author: m.lipson@unsw.edu.au
# Description: 
# This is a script run once a day to backup observations
# It is run through crontab, editable with:
# 	crontab -e

import os
import time

# set path for local or server
if (os.getenv('HOME') == '/home/ubuntu'):
	fullpath = '/srv/isithotrightnow'
else:
	fullpath = '.'

# set day
today = time.strftime("%y%m%d")

# create directory if not existing
if not os.path.exists("%s/databackup" %(fullpath)):
	os.makedirs("%s/databackup" %(fullpath))
if not os.path.exists("%s/imgbackup" %(fullpath)):
	os.makedirs("%s/imgbackup" %(fullpath))

# make backup with todays date
os.system('cp %s/data/latest/latest-all.csv %s/databackup/%s-all.csv' %(fullpath,fullpath,today))

# make backup of timeseries
for site in ['009021','014015','015590','023090','040842','066062','067105','070351','087031','094029']:
	os.system('cp %s/www/output/ts_plot.png %s/imgbackup/%s-ts-%s.png' %(fullpath,fullpath,site,today))

