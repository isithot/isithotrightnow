import numpy as np
import pandas as pd

# read max temperature percentiles for each day
productid='IDCJAC0010'
stationid='066062'
tmax=pd.read_csv('data/%s_%s_1800_Data.csv' %(productid,stationid),usecols=[2,3,4,5])
tmax.index = pd.to_datetime(tmax[['Year','Month','Day']])
# read min temperature percentiles for each day
productid='IDCJAC0011'
tmin=pd.read_csv('data/%s_%s_1800_Data.csv' %(productid,stationid),usecols=[2,3,4,5])
tmin.index = pd.to_datetime(tmin[['Year','Month','Day']])

# 90th percentile
tmax90p = tmax['Maximum temperature (Degree C)'].groupby([lambda x : x.month,lambda x : x.day]).quantile(.90)
tmin90p = tmin['Minimum temperature (Degree C)'].groupby([lambda x : x.month,lambda x : x.day]).quantile(.10)
tmax90p=tmax90p.round(decimals=2)
tmin90p=tmin90p.round(decimals=2)
tmax90p.to_csv('data/tmax90p_%s.csv' %stationid)
tmin90p.to_csv('data/tmin90p_%s.csv' %stationid)



