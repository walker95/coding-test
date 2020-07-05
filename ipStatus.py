from datetime import datetime
from icmplib import ping
import time

ip = '10.10.12.253'
gw = '10.10.12.1'
def pingIP(ip, gw):
    if ping(ip).is_alive:
        if ping(gw).is_alive:
            print(ip + gw + "alive")
        else:
            print(gw + "down")
            downtime = time.strftime('%M')
            print(downtime)
    else:
        print(ip + "down")
        downtime = time.strftime('%M')
        print(downtime)

pingIP(ip, gw)



        










