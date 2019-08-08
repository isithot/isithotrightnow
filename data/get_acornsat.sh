#!/bin/bash

for SITE in 014015 015590 066062 070351 067105 040842 023090 094029 087031 009021 ; do

	curl http://www.bom.gov.au/climate/change/acorn/sat/data/acorn.sat.maxT.$SITE.daily.txt > acorn.sat.maxT.$SITE.daily.txt
	curl http://www.bom.gov.au/climate/change/acorn/sat/data/acorn.sat.minT.$SITE.daily.txt > acorn.sat.minT.$SITE.daily.txt

done