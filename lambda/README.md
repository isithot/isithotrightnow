# Is it hot right now: `/lambda`

Microservices for Is it hot right now.

Most of these services run in Python and contain one service per folder. They are deployed to AWS Lambda manually.

The plotting functions are all written in R, and are all contained in a single folder, `createPlots`. When the default `lambda` branch is pushed, the R Lambdas are built as a single Docker image automatically (see [`build-upload-docker.yml`](/.github/workflows/build-upload-docker.yml)) and uploaded to the AWS Elastic Container Registry. However, the relevant Lambdas are not updated automatically; you will still need to go to the Lambda console and deploy the new image for each one, selecting the newly uploaded image. (The build and upload takes approximately 5 minutes.)

## Current deployments

The Lambdas currently deployed are:

### Daily

`loop_getHistorical`
- Load location list `1-datasources/locations.json`
- Calls `getHistoricalObs` for each station

`getHistoricalObs`
- Read + merge ACORN-SAT tmax + tmin
- Calculate Tavg
- Filter to 14-day window
- Upload window obs to S3 as `2-processed/historical_{stationid}.txt`

### Every 15 mins

`getLatestObs`
- Gets BOM current observations from FTP
- Extracts obs of interest for all our stations
- Downloads today’s tmax/tmin so far from 1-datasources/latest/latest-all.csv
- Choose whether to use new incoming obs or retain current ones
- Flag the stations for which new incoming obs have been used (“dirty” stations)
- Write `1-datasources/latest/latest-all.csv` back out
- For each dirty station:
  - Invoke `processCurrentObs`, passing latest ob for the day w/ station data
Invoke `processStatsAll`

`processStatsAll`
- Takes all the `www/stats/stats_{stationid}.txt` and condenses them into one JSON file, `www/stats/stats_all.json`

`processCurrentObs`
- Load location list `1-datasources/locations.json`
- Latest ob: calc Tavg = Tmax + Tmin
- Load window obs `2-processed/historical_{stationid}.txt`
- Calc percentiles from window obs
- Categorise latest ob
- Derive answer and comment from category
- Calculate pct of window obs lower than current temp (is this happening twice?)
- Build stats dictionary
- Write stats dictionary out `www/stats/stats_{station_id}.json`
- Invoke `createTimeseriesPlot`
- Invoke `createDensityPlot`
- Read yearly file, if it exists `2-processed/{stationid}-year.csv`
- If it doesn’t, read each existing date file for the year and combine
- Add current observation and percentile
- Write out year-to-date file
- Invoke `createHeatmapPlot`

