Readme for observation data
===========================

There are a few relevant codes used by the BOM and WMO:
* WMO station ID code: a five digit code (eg. 94768 for Sydney Obs Hill)
  - Australian stations are all in the 94100–94998 range
* BOM station ID code: a six digit code (eg. 066062 for Sydney Obs Hill):
  - Digit 1: type of station (0 = land-based)
  - Digits 2–3: region (regions can be used to infer states: see repo README)
* A BoM _product_ code. Some products are for a single station, but the product code is distinct from station codes (some include a WMO station code, though):
  - "ID"
  - State letter (see repo README): eg. N for NSW, Q for QLD, V for VIC, etc)
  - 60901 = product number
  - 94768 = WMO station number (used in current obs)

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


Sites
=====

| Site                  | Location      | State | BOM ID | Start | End  | Live? |
|-----------------------|---------------|-------|--------|-------|------|-------|
| Richmond RAAF         | Sydney        | NSW   | 067105 | 1939  | 2017 | N     |
| Observatory Hill      | Sydney        | NSW   | 066062 | 1910  | 2017 | Y     |
| Laverton RAAF         | Melbourne     | VIC   | 087031 | 1943  | 2017 | N     |
| Canberra Airport      | Canberra      | ACT   | 070351 | 1939  | 2017 | N     |
| Hobart (Ellerslie Rd) | Hobart        | TAS   | 094029 | 1918  | 2017 | N     |
| Brisbane Aero         | Brisbane      | QLD   | 040842 | 1949  | 2017 | N     |
| Kent Town             | Adelaide      | SA    | 023090 | 1910  | 2017 | N     |
| Alice Springs Airport | Alice Springs | NT    | 015590 | 1910  | 2017 | N     |
| Darwin Airport        | Darwin        | NT    | 014015 | 1910  | 2017 | N     |
| Perth Airport         | Perth         | WA    | 009021 | 1910  | 2017 | N     |


OLD
===

Monthly Max/Min temperatures per station
----------------------------------------

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



