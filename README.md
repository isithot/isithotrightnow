# isithotrightnow
Is it hot right now?

Written in R with scripts to download data, create stats and plots run every 10 minutes.

-----

Yearly maintenance: 

- Add www/output/[stationID] to git repository
- If missing XXXXX-all.csv, run `python databackup/populate_daily-all_files.py` with missing year/months
- run `Rscript databackup/records-tidy.r`

