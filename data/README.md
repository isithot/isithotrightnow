Readme for observation data
===========================

There seems to be two station ID formats in use by BOM. 
Eg Sydney has IDN60901.94768 and 066062
* ID = ID
* N = NSW (Q=QLD, V=VIC etc)
* 60901 = product number
* 94768 = station number (used in current obs)

* 066062 = also station number (used in long historical record files)

We will stick with IDN60901.94768 for now as those files are downloaded every half hour.

Current Observations
====================

* IDN60901: product code
* 94768: ? ID (different to station ID)

Current observations html (syd obs) 
http://www.bom.gov.au/products/IDN60901/IDN60901.94768.shtml

JavaScript Object Notation format (JSON) in row-major order
http://www.bom.gov.au/fwo/IDN60901/IDN60901.94768.json

Historical Daily Max/Min temperatures per station
=================================================

http://www.bom.gov.au/climate/data/stations/
Select location and data type. Max/min data is free

ACORN-SAT stations
==================

Australian data:
http://www.bom.gov.au/climate/change/acorn-sat/#tabs=Data-and-networks

Sydney data:
http://www.bom.gov.au/climate/change/acorn/sat/data/acorn.sat.minT.066062.daily.txt
http://www.bom.gov.au/climate/change/acorn/sat/data/acorn.sat.maxT.066062.daily.txt

station catalogue useful when we start expanding:
http://www.bom.gov.au/climate/change/acorn-sat/documents/ACORN-SAT-Station-Catalogue-2012-WEB.pdf

XML Feeds
=========
General: http://www.bom.gov.au/catalogue/data-feeds.shtml
Anonymous: http://www.bom.gov.au/catalogue/anon-ftp.shtml
Index: ftp://ftp.bom.gov.au/anon/gen/fwo/
NSW: ftp://ftp.bom.gov.au/anon/gen/fwo/IDN60920.xml

Monthly Max/Min temperatures per station
========================================

Source: [http://www.bom.gov.au/climate/data/stations/](http://www.bom.gov.au/climate/data/stations/)
currently need to go through GUI
possibly download direct as zip file from something like
http://www.bom.gov.au/jsp/ncc/cdio/weatherData/av?p_display_type=dailyZippedDataFile&p_stn_num=066062&p_nccObsCode=123&p_c=-872886919&p_startYear=1859

IDCJAC0010\_066062\_1800_Data.csv
---------------------------------

* IDCJAC0010: product code - daily **maximum** temperature
* 066062: station number - Sydney observatory
* 1800: time period (s)

IDCJAC0011\_066062\_1800_Data.csv
---------------------------------

* IDCJAC0011: product code - daily **minimum** temperature
* 066062: station number - Sydney observatory
* 1800: time period (s)

Daily max/min temperatures per station
======================================

Python code calculates 90th percentile for daily max and min data for each day going back to 1859 (for sydney)
calc_maxmin.py

tmax90p_066062.csv
------------------

tmin90p_066062.csv
------------------

BOM calculated climatology
==========================

From website
[http://www.bom.gov.au/climate/averages/tables/cw_066062_All.shtml](http://www.bom.gov.au/climate/averages/tables/cw_066062_All.shtml)
Website allows splitting into 10,20,30 year periods.
But CSV only allows all data (since 1859)



