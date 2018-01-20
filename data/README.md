
Historical data
===============

Historical data for each site is based on the Bureau of Meteorology's [ACORN-SAT](http://www.bom.gov.au/climate/change/acorn-sat/) high quality dataset. Some sites do not have current or historical sites available in the centre of the city. In those cases the town airport is used, as listed below.

Sites
-----

| BOM ID | Site                  | Location                | State | Start | End  | Live? |
|--------|-----------------------|-------------------------|-------|-------|------|-------|
| 066062 | Observatory Hill      | Sydney - City           | NSW   | 1910  | 2017 | Y     |
| 067105 | Richmond RAAF         | Sydney - West           | NSW   | 1939  | 2017 | Y     |
| 087031 | Laverton RAAF         | Melbourne  - West       | VIC   | 1943  | 2017 | Y     |
| 070351 | Canberra Airport      | Canberra - Airport      | ACT   | 1939  | 2017 | Y     |
| 094029 | Hobart (Ellerslie Rd) | Hobart - Ellerslie Rd   | TAS   | 1918  | 2017 | Y     |
| 040842 | Brisbane Aero         | Brisbane - Airport      | QLD   | 1949  | 2017 | Y     |
| 023090 | Kent Town             | Adelaide - Kent Town    | SA    | 1910  | 2017 | Y     |
| 015590 | Alice Springs Airport | Alice Springs - Airport | NT    | 1910  | 2017 | Y     |
| 014015 | Darwin Airport        | Darwin - Airport        | NT    | 1910  | 2017 | Y     |
| 009021 | Perth Airport         | Perth - Airport         | WA    | 1910  | 2017 | Y     |

For more sites, check out the whole [ACORN-SAT network](http://www.bom.gov.au/climate/change/acorn-sat/#tabs=Data-and-networks).

For site descriptions, check out the [BOM Station Catalogue](http://www.bom.gov.au/climate/change/acorn-sat/documents/ACORN-SAT-Station-Catalogue-2012-WEB.pdf).

Current observations
====================

Current observations are based on XML [data feeds](http://www.bom.gov.au/catalogue/data-feeds.shtml) from the Bureau.

* <a href="ftp://ftp.bom.gov.au/anon/gen/fwo/IDN60920.xml">New South Wales & Canberra</a>
* <a href="ftp://ftp.bom.gov.au/anon/gen/fwo/IDD60920.xml">Northern Territory</a>
* <a href="ftp://ftp.bom.gov.au/anon/gen/fwo/IDQ60920.xml">Queensland</a>
* <a href="ftp://ftp.bom.gov.au/anon/gen/fwo/IDS60920.xml">South Australia</a>
* <a href="ftp://ftp.bom.gov.au/anon/gen/fwo/IDV60920.xml">Victoria</a>
* <a href="ftp://ftp.bom.gov.au/anon/gen/fwo/IDW60920.xml">Western Australia</a>
* <a href="ftp://ftp.bom.gov.au/anon/gen/fwo/IDT60920.xml">Tasmania and ... Antarctica (coming soon???)</a>

BoM product info
================

Each state is associated with a letter, used in product codes (`IDx`, where `x` is the state letter), and a range of regions, [used in station IDs](http://www.bom.gov.au/climate/cdo/about/site-num.shtml#tabulated) (`XYYnnn`, where `YY` is the region number).

State     | Product letter | Regions
----------|----------------|-------
WA        | W              | 1–13
NT        | D              | 14–15
SA        | S              | 16–26
Qld       | Q              | 27–45
NSW & ACT | N              | 46–75
Vic       | V              | 76–90
Tas       | T              | 91–99


Other Current Observations Formats
==================================

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

* General: http://www.bom.gov.au/catalogue/data-feeds.shtml
* Anonymous: http://www.bom.gov.au/catalogue/anon-ftp.shtml
* Index: ftp://ftp.bom.gov.au/anon/gen/fwo/
* NSW: ftp://ftp.bom.gov.au/anon/gen/fwo/IDN60920.xml


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



