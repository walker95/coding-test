"""
    Date: 10-Oct-2019
    Description: It will run on cloud system and monitor all local system. If anything critical happened, it will responsed immediately.
"""
import os,re,random
import json
import socket
import subprocess
from datetime import datetime,timedelta
import redis
from json2html import *
from config import MONIOTORING_TIME,CLOUD_REDIS_IP,CLOUD_REDIS_PORT,CLOUD_REDIS_PORT,CLOUD_REDIS_PASSWORD,CLOUD_REDIS_DB,emailCredentials
import pymongo
from mailer import Mailer
from mailer import Message
from time import sleep

LOCAL_MONITOR_HOSTS = ["mirror-prime","bumblebee","ironhide","thanos"]
cloudRedisConn = redis.Redis(host=CLOUD_REDIS_IP, port=CLOUD_REDIS_PORT, password=CLOUD_REDIS_PASSWORD, db=CLOUD_REDIS_DB)
mongourl = 'mongodb://localhost:27019/'
mongodbLocalClient = pymongo.MongoClient(mongourl,serverSelectionTimeoutMS=5000)
modeMail = True
timeThreshold = 900 #15 mins
MAILING_LIST = ["varun.kumar@silverpush.co","amit@silverpush.co","vikash@silverpush.co","vrns.iitd@gmail.com"]
HTML_FILE_PATH = '/var/www/html/monitoring.html'
db = mongodbLocalClient.critical
collection = db.monitoring
def main():
    try:
        ####### YOUTUBE_DL BLOCKING NOTIFICATION #########
        try:
            ytdlBlocked()
        except:
            pass
        ###############
        listOfDetails = []
        f = open(HTML_FILE_PATH,'w')
        print("MONITORING TIME:",str(datetime.now()))
        for hostname in LOCAL_MONITOR_HOSTS:
            data = {}
            rdata = cloudRedisConn.get(hostname)
            print("hostname:", hostname,"data=>",rdata)
            
            if rdata:
                data = json.loads(rdata)
                data['total_storage'] = str(data['total_storage']/1000000000)+'GB'
                data['total_memory'] = str(data['total_memory']/1000000000)+'GB'
                data['pfmemory'] = str(data['pfmemory'])+'%'
                data['pfstorage'] = str(data['pfstorage'])+'%'
                pass
            else:
                #Some Critical situation created on host
                print("Some Critical Situation on %s"%hostname)
                msg="CRITICAL_LEVEL_10"
                criteria = sendingCriteria(hostname,msg=msg)
                subject = "MIRROR_MONITORING: "
                subject+=hostname+ ':URGENT '+msg
                body = "Dear Mirror, \n\n HOST <{hostname}> is in critical situation. \n\n POSSIBLE REASONS:\n\n 1. SYSTEM IS DOWN. \n\n 2. INTERNET IS DOWN. \n\n 3. INTERNAL NETWOKING MISCONFIGURATION. \n\n 4. MONITORING SCRIPT IS NOT RUNNING. \n\n TAKE ACTIONS IF REQUIRED ELSE IGNORE. WILL SEE YOU AGAIN AFTER {time} mins.".format(hostname=hostname,time = str(timeThreshold/60))
                
                sendMail(criteria,hostname,subject,body,msg)
            data['hostname'] = hostname
            listOfDetails.append(data)
        print(listOfDetails)
        html = '<html> '
        html+=json.dumps(LOCAL_MONITOR_HOSTS)
        html += json2html.convert(json = listOfDetails)
        html+='<html>'
        f.write(html)
        f.close()
        print(html)
    except Exception as e:
        print("Exception in main() ",str(e),datetime.now())

def ytdlBlocked():
    try:
        bhosts = cloudRedisConn.scan(0,'*ytapi*')[1]
        if bhosts:
            for host in bhosts:
                try:
                    bhostname = host.decode("utf-8").split('?')[0]
                    pubip =  host.decode("utf-8").split('?')[-1]
                    print("blocked hosts:",bhostname)
                    print('\n\n',"Send Mail",str(datetime.now()))
                    msg="YOUTUBE BLOCKED IP :%s"%pubip
                    criteria = sendingCriteria(bhostname,msg=msg)
                    
                    subject = "MIRROR_MONITORING: "
                    subject+=bhostname+ ':URGENT '+msg
                    body = "Dear Mirror, \n\n HOST <{hostname}> is in critical situation. \n\n YOUTUBE BLOCKED THE IP:{ip} \n\n WILL SEE YOU AGAIN AFTER {time} mins.".format(hostname=bhostname,time = str(timeThreshold/60),ip=pubip)
                    sendMail(criteria,bhostname,subject,body,msg)
                except IndexError:
                    pass
                except Exception:
                    pass
    except Exception as e:
        print("Exception in ytdlBlocked: ",str(e),str(datetime.now()))

def emailer(Subject, Body, msg, script='mirror', mailingList=MAILING_LIST, attachment=''):
    try:
        if modeMail:
            message = Message(From="help@silverpush.co", To=mailingList, Subject=Subject)
            message.Body = Body
            if attachment != '':
                message.attach(attachment)
            sender = Mailer('smtp.gmail.com', use_tls=True, usr='help@silverpush.co', pwd='sphelp@2020')
            sender.send(message)
        
        print(Subject,Body+str(script))
        return True
    except Exception as e:
        print "Exception caught in emailer - {0}".format(e),type(e),datetime.now()
        return False
def sendMail(criteria,hostname,subject,body,msg):
    try:
        if criteria==1:
            #need to update and send mail.
            print("NEW UPDATE")
            sendmail =  emailer(subject,body,msg)
            print(subject,body,msg)
            if sendmail:
                dataToUpdate = {
                "lastMailTime":datetime.now()
                }
                collection.update_one({"hostname":hostname,"msg":msg},{"$set":dataToUpdate})
        elif criteria==2:
            #need to insert and send mail.
            print("NEW INSETION")
            sendmail =  emailer(subject,body,msg)
            print(subject,body,msg)
            if sendmail:
                dataToUpdate = {
                "hostname":hostname,
                "msg":msg,
                "lastMailTime":datetime.now()
                }
                collection.insert_one(dataToUpdate)
        else:
            #Nothing to do.
            pass
    except Exception as e:
        print("Exception in sendMail: ",str(e),str(datetime.now()))
def sendingCriteria(hostname,msg='CRITICAL'):
    try:
        db = mongodbLocalClient.critical
        collection = db.monitoring
        results = collection.find_one({"hostname":hostname,"msg":msg})
        if results:
            lastMailTime = results.get('lastMailTime')
            if lastMailTime:
                if (datetime.now()-lastMailTime).total_seconds() >= timeThreshold:
                    return 1
        else:
            return 2
        return -1
    except Exception as e:
        print("Exception in sendingCriteria: ",str(e),str(datetime.now()))

# while True:
#   try:
#       print("MONITORING STARTED:",str(datetime.now()))
#       main()
#       sleep(MONIOTORING_TIME)
#   except Exception as e:
#       print("Exception ",str(e),str(datetime.now()))
#       sleep(60)
main()