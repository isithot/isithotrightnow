Data from the following sources:

Monthly Max/Min temperatures per station
======================================

Source: [http://www.bom.gov.au/climate/data/stations/](http://www.bom.gov.au/climate/data/stations/)
currently need to go through GUI
possibly download direct as zip file from something like
http://www.bom.gov.au/jsp/ncc/cdio/weatherData/av?p_display_type=dailyZippedDataFile&p_stn_num=066062&p_nccObsCode=123&p_c=-872886919&p_startYear=1859

IDCJAC0010\_066062\_1800_Data.csv
---------------------------------

* IDCJAC0010: product code - daily **maximum** temperature
* 066062: station number - Sydney observatory
* 1800: ???

IDCJAC0011\_066062\_1800_Data.csv
---------------------------------

* IDCJAC0011: product code - daily **minimum** temperature
* 066062: station number - Sydney observatory
* 1800: ???

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



