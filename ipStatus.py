from datetime import datetime
from icmplib import ping

ip = '10.10.12.24'
gw = '10.10.11.22'

def ipStatus(ip, gw):
    now = datetime.now()
    if ping(ip).is_alive:
        if ping(gw).is_alive:
            print("ip and gw are up..")
            sent = False
        else:
            print("gw is down. shoot mail...")
            mailer()
    else:
        return "ip is down. shoot mail..."
        mailer()

def mailer():
    sent = False
    if sent == False:
        print("mail needs to be sent")
        mailtime = datetime.now().minute
    elif datetime.now().minute == mailtime:
        print("mail needs to be sent")

ipStatus(ip, gw)



