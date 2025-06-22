# Creation of locations.json

ACORN-SAT data refers to a master station list file:

> ACORN-SAT v2.3 station data for 112 sites listed in acorn_sat_v2.3_stations.txt

However I can't find this file on the website, nor in the FTP files. 
The ACORN-SAT ["metadata"](http://www.bom.gov.au/metadata/catalogue/19115/ANZCW0503900725) page is currently a broken link (as of 22 Jun 25).

So to update, the locations.json, I'm copying from the website table here:
http://www.bom.gov.au/climate/data/acorn-sat/#tabs=Data-and-networks
pasting into excel and creating a csv.

Then using `create_locations.py` to convert the csv to our json format.
This captures all important information except the location timezone.

I therefore need to install a python package: `timezonefinder`, which seems to do a good job.


