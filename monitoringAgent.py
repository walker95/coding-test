#!/usr/bin/env python3
#requirements: statgrab, nstat, psutil, netifaces, ip
from subprocess import check_output
from json import loads
from psutil import process_iter, cpu_count, cpu_freq, cpu_percent, cpu_stats, cpu_times, cpu_times_percent
import netifaces as nf 
from datetime import datetime as dt
from pymongo import MongoClient as client
from os import uname
import schedule
from datetime import datetime as dt
from time import sleep
HOST = '10.10.12.71'
PORT = 27017
conn = client(host=HOST, port=PORT)
db = conn['monitoring']
collection = db[dt.now().strftime("%d-%m")]

def upTime(seconds):
    seconds_in_day = 60 * 60 * 24
    seconds_in_hour = 60 * 60
    seconds_in_minute = 60
    days = seconds // seconds_in_day
    hours = (seconds - (days * seconds_in_day)) // seconds_in_hour
    minutes = (seconds - (days * seconds_in_day) - (hours * seconds_in_hour)) // seconds_in_minute
    return f"{days} days,{hours} hours,{minutes} minutes"

def metrix():
    statdict = {}
    dict1 = {
            "cpu_count": cpu_count(),
            "cpu_freq": cpu_freq(),
            "cpu_percent": cpu_percent(),
            "cpu_stats": cpu_stats(),
            "cpu_times": cpu_times(),
            "cpu_times_percent": cpu_times_percent()
            }
    cmd = ["statgrab", '-F', "ext4,xfs,zfs,exfat,fat32"]
    out = check_output(cmd).decode('utf-8').splitlines()
    for obj in out:
        obj = obj.strip().replace(".", "_").split(' = ')
        dict1[f"{obj[0]}"] = f"{obj[1]}"
        statdict = {
                "_id": "1",
                "stats": dict1
                }
    if col.find_one({"_id": "1"}):
        x = col.update_one({"_id": "1"}, {"$set":{"stats": dict1}})
        return f" ID: 1, acknowledgement: {x.acknowledged}"
    else:
        x = col.insert_one(statdict)
        return f"ID: {x.inserted_id}"

def installedApps():
	apps = {}
	cmd = ['apt', 'list', '--manual-installed', '--upgradable']
    out = check_output(cmd).decode('utf-8').splitlines()
    out.pop(0)
    apps = {
    "_id": "2",
    "installedApps": out
    }
    if col.find_one({"_id": "2"}):
        x = col.update_one({"_id": "2"}, {"$set":{"installedApps": out}})
        retunr f" ID: 2, acknowledgement: {x.acknowledged}"
    else:
        x = col.insert_one(apps)
        retunr f"ID: {x.inserted_id}"

def ips():
	inets = {}
    cmd = ['ip','-j','a']
    out = loads(check_output(cmd).decode('utf-8'))
    inets = {
    "_id": "3",
    "ips": out
    }
    if col.find_one({"_id": "3"}):
        x = col.update_one({"_id": "3"}, {"$set":{"ips": out}})
        return f" ID: 3, acknowledgement: {x.acknowledged}"
    else:
        x = col.insert_one(inets)
        return f"ID: {x.inserted_id}"

# def ipStat():
#     cmd = ["nstat", "-j"]
#     return loads(check_output(cmd).decode('utf-8'))

def pStat():
	for ps in process_iter():
	    psDict[f"{ps.pid}"] = ps.as_dict()
	processes = {
	"_id": "4",
	"ps": psDict
	}
	if col.find_one({"_id": "4"}):
        x = col.update_one({"_id": "4"}, {"$set":{"ps": psDict}})
        return f" ID: 4, acknowledgement: {x.acknowledged}"
    else:
        x = col.insert_one(processes)
        return f"ID: {x.inserted_id}"

schedule.every(10).seconds.do(metrix)
schedule.every().day.at("00:05").do(installedApps)
schedule.every(1).hour.do(ips)
schedule.every(10).minutes.do(pStat)

while True:
	schedule.run_pending()
	sleep(5)






