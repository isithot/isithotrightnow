# %%
from ftplib import FTP
import pandas as pd
# %%
with FTP("ftp.bom.gov.au") as ftp:
    ftp.login()
    ftp.cwd("anon/home/ncc/www/change/ACORN_SAT_daily")
    files = pd.DataFrame(ftp.nlst(), columns=["Name"])
# %%
files = files[files.Name.str.contains("acorn_sat_v.*_daily_t.{3}\.tar\.gz")]
files['Version'] = files['Name'].str.extract('acorn_sat_(.*)_daily_t.{3}\.tar\.gz')
latest_version = files.sort_values('Version').Version.iloc[-1]
latest_tmax_file = files[files.Name.str.contains("tmax")].sort_values('Version').Name.iloc[-1]
latest_tmin_file = files[files.Name.str.contains("tmin")].sort_values('Version').Name.iloc[-1]
# %%
with open('latest_ACORN-SAT_version.md', 'r') as f:
    current_version = f.readline()
# %%
if latest_version > current_version:
    with FTP("ftp.bom.gov.au") as ftp:
        ftp.login()
        ftp.cwd("anon/home/ncc/www/change/ACORN_SAT_daily")
        files = pd.DataFrame(ftp.nlst(), columns=["Name"])
        with open(latest_tmax_file,"wb") as ftmax:
            ftp.retrbinary(f"RETR {latest_tmax_file}", ftmax.write)
        with open(latest_tmin_file,"wb") as ftmin:
            ftp.retrbinary(f"RETR {latest_tmin_file}", ftmin.write)

    with open('latest_ACORN-SAT_version.md', 'w') as f:
        f.write(latest_version)
# %%
