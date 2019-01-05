import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patheffects as path_effects
import pandas as pd
from scipy import stats
import sys
import os

siteids = ['014015','015590','066062','070351','067105','040842','023090','094029','087031','009021']
sitenames = ['Darwin Airport','Alice Springs Airport','Sydney Observatory Hill',
                'Canberra Airport','Richmond RAAF','Brisbane Airport','Adelaide Kent Town',
                'Hobart Ellerslie Road','Melbourne (Laverton RAAF)','Perth Airport']

hist_min = dict()
hist_max = dict()
hist_avg = dict()
year_avg = dict()
current = dict()

def plot_ols(x, y, label, ax, colour='b',lw=0.75,ms=2,trend=True,scatter=True):
    '''function that plots scatter and OLS line from data x, y'''
    if scatter:
        # plot scatter points
        ax.plot(x,y,
            color=colour, marker='o', markerfacecolor='None',
            markeredgecolor=colour, markeredgewidth=0.75,
            markersize=ms, ls='solid',lw=lw, alpha=0.5, label=None)
    if trend:
        # calculate and plot linear regression
        slope, intercept, r, p, stderr = stats.linregress(x, y)
        ax.plot((x[0],x[-1]),(intercept+x[0]*slope,intercept+x[-1]*slope),
            color=colour,label='Trend %.1f °C/century' %(slope*100))
    return ax

# days in month
ndays = [31,28,31,30,31,30,31,31,30,31,30,31]

for siteid in siteids:
    # read historical temperatures from ACORN.SAT
    hist_min[siteid] = pd.read_csv('data/acorn.sat.minT.%s.daily.txt' %siteid, 
        skiprows = [0],
        header = None, 
        names = ['date','temp'], 
        na_values = [99999.9],
        delim_whitespace = True, 
        parse_dates = [0],
        index_col = [0])
    hist_max[siteid] = pd.read_csv('data/acorn.sat.maxT.%s.daily.txt' %siteid, 
        skiprows = [0], 
        header = None, 
        names = ['date','temp'], 
        na_values = [99999.9],
        delim_whitespace = True,
        parse_dates = [0],
        index_col = [0])

    hist_avg[siteid] = (hist_min[siteid] + hist_max[siteid])/2
    year_avg[siteid] = hist_avg[siteid].groupby(hist_avg[siteid].index.year).mean()

    # read yearly percentile
    current[siteid] = pd.read_csv('databackup/%s-2018.csv' %siteid, 
        parse_dates=[0], index_col=[0])

### get tmin and tmax into year frame using daily-all.csv records ###

# loop through sites
for siteid in siteids:
    # loop through month and days of year
    for imonth in range(1,len(ndays)+1):
        for iday in range(1,ndays[imonth-1]+1):

            # create filled string for day/month
            sday = str(iday).zfill(2)
            smonth = str(imonth).zfill(2)

            # open current day -all frame
            day = pd.read_csv('databackup/18%s%s-all.csv' %(smonth,sday),dtype={'station_id':str})

            # place min/max of current day from -all.csv frame into year[site] dictionary
            current[siteid].loc['2018-%s-%s' %(smonth,sday),'tmax'] = day[day.station_id==siteid]['tmax'].values
            current[siteid].loc['2018-%s-%s' %(smonth,sday),'tmin'] = day[day.station_id==siteid]['tmin'].values
            # calculate daily average
            current[siteid].loc['2018-%s-%s' %(smonth,sday),'tavg'] = (current[siteid].loc['2018-%s-%s' %(smonth,sday),'tmax'] + 
                                                                    current[siteid].loc['2018-%s-%s' %(smonth,sday),'tmin'])/2

            # place this year avg tempearture in historical records
            year_avg[siteid].loc[2018,'temp'] = current[siteid].loc[:,'tavg'].mean()

# remove incomplete records
year_avg['067105'].loc[1939,'temp'] = np.nan
year_avg['067105'].loc[1940,'temp'] = np.nan
year_avg['067105'].loc[1946,'temp'] = np.nan
year_avg['009021'].loc[1942,'temp'] = np.nan
year_avg['009021'].loc[1943,'temp'] = np.nan

# plot
for siteid,sitename in zip(siteids,sitenames):

    plt.close('all')
    fig, ax = plt.subplots(nrows=1,ncols=1,figsize=(7,4))
    ax.set_title('%s yearly average temperature' %sitename,fontsize=12)
    ax.set_ylabel('Temperature (°C)', fontsize=12)

    rank = (year_avg[siteid][year_avg[siteid]>year_avg[siteid].loc[2018]].count() + 1).values[0]

    # plot
    # year_avg[siteid][1:].plot(ax=ax,legend=False,color='black', lw=1,alpha=0.5,marker='x',ms=3)
    plot_ols( x=year_avg[siteid][1:].index.values, y=year_avg[siteid][1:].values[:,0], 
        label='Yearly Avg.', ax=ax, colour='black', trend=True, scatter=True)

    handles,labels = ax.get_legend_handles_labels()

    # 2018 marker
    year_avg[siteid].loc[[2018]].plot(ax=ax,marker='s',ms=7,color='crimson',legend=False)
    ax.set_ylim(bottom=year_avg[siteid].min().values[0]-0.5,top=year_avg[siteid].max().values[0]+0.5)

    thisyr = year_avg[siteid].loc[[2018]].values[0]
    thistxt = ax.text(2018,thisyr+0.15,
        '2018: %2.1f°C \n ranked: %s' %(thisyr,rank),
        color='crimson',ha='center',va='bottom',family='sans-serif',weight='bold')

    thistxt.set_path_effects([path_effects.Stroke( linewidth=2, foreground='white'),path_effects.Normal()])
    ax.yaxis.set_ticks_position('both')

    plt.legend(handles = handles, labels=labels, ncol=1,fontsize=8,loc='upper left')

    fig.savefig('figures/yrt_avg_%s.png' %(siteid), dpi=300,bbox_inches='tight',pad_inches=0.05)

for siteid,sitename in zip(siteids,sitenames):
    year_sort = year_avg[siteid].sort_values(by='temp',ascending=False)
    rank = (year_avg[siteid][year_avg[siteid]>year_avg[siteid].loc[2018]].count() + 1).values[0]
    print('')
    print(sitename)
    print('2018 ranks %s' %(rank))
    print(year_sort.head(n=10).round(2))


# ## winter months
# season = [6,7,8]
# siteid = '070351' # canberra
# sitename = 'Canberra Airport'

# current_win = current[siteid].loc[current[siteid].index.month.isin(season)]
# hist_avg_win = hist_avg[siteid].loc[hist_avg[siteid].index.month.isin(season)]

# year_avg_win = hist_avg_win.groupby(hist_avg_win.index.year).mean()
# year_avg_win.loc[2018,'temp']  = current_win.loc[:,'tavg'].mean()


# #### winter plot
# plt.close('all')
# fig, ax = plt.subplots(nrows=1,ncols=1,figsize=(7,4))
# ax.set_title('%s winter average temperature' %sitename,fontsize=12)
# ax.set_ylabel('Temperature (°C)', fontsize=12)

# rank = (year_avg_win[year_avg_win>year_avg_win.loc[2018]].count() + 1).values[0]

# # line plot
# year_avg_win[1:].plot(ax=ax,legend=False,color='black', lw=1,alpha=0.5,marker='x',ms=3)
# # 2018 marker
# year_avg_win.loc[[2018]].plot(ax=ax,marker='s',ms=7,color='crimson',legend=False)
# ax.set_ylim(bottom=year_avg_win.min().values[0]-0.5,top=year_avg_win.max().values[0]+0.5)

# thisyr = year_avg_win.loc[[2018]].values[0]
# thistxt = ax.text(2018,thisyr-0.15,
#     '2018: %2.1f°C \nranked: %s' %(thisyr,rank),
#     color='crimson',ha='center',va='top',family='sans-serif',weight='bold')

# thistxt.set_path_effects([path_effects.Stroke( linewidth=2, foreground='white'),path_effects.Normal()])
# ax.yaxis.set_ticks_position('both')

# fig.savefig('figures/winter_avg_%s.png' %(siteid), dpi=300,bbox_inches='tight',pad_inches=0.05)

