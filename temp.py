#!/usr/bin/python3

import json
import pprint
import os
from datetime import datetime as dt
import psutil
import requests
import getpass
import platform
import uptime
import subprocess
import netifaces as nf

if psutil.LINUX is True:
    dist = platform.dist()
elif psutil.MACOS is True:
    dist = platform.platform()

systemType = platform.uname().system
KernalVersion = platform.release()
upSince = str(dt.now() - dt.fromtimestamp(psutil.boot_time()))

partitions = psutil.disk_partitions()

interface = nf.gateways().get('default').get(2)[1]
public_ip = requests.get('https://api.ipify.org')
network_io = psutil.net_io_counters()
def get_size(bytes, suffix="B"):
    """
    Scale bytes to its proper format
    e.g:
        1253656 => '1.20MB'
        1253656678 => '1.17GB'
    """
    factor = 1000
    for unit in ["", "K", "M", "G", "T", "P"]:
        if bytes < factor:
            return f"{bytes:.2f}{unit}{suffix}"
        bytes /= factor

def get_pid(name):
    return int(check_output(["pidof","-s",name]))

diskCritical = False
if float(psutil.disk_usage(psutil.disk_partitions()[0].mountpoint).percent) > 80:
    diskCritical = True


main = {
    # 'hostname': os.uname().nodename,
    'infra': {
        'sysType': platform.uname().system,
    	'osType_Version_Release': dist,
    	'cpuCount': psutil.cpu_count(),
    	'loadAvarage': psutil.getloadavg()[0],
    	'infrastructure': platform.uname().machine,
    	'KernalVersion': platform.uname().release
    },
    'system': {
    	'hostname': platform.node(),
    	'uptime': str(upSince)
    },
    'physicalMem': {
    	'total': get_size(psutil.virtual_memory().total),
    	'used': get_size(psutil.virtual_memory().used),
    	'usedPercent': psutil.virtual_memory().percent,
    	'available': get_size(psutil.virtual_memory().free)
    },
    'swapMem': {
    	'total': get_size(psutil.swap_memory().total),
    	'used': get_size(psutil.swap_memory().used),
    	'percent_used': psutil.swap_memory().percent,
    	'available': get_size(psutil.swap_memory().free)
    },
    'disk': {
    	'partition0': {
                'device': partitions[0].device,
                'mountpoint': partitions[0].mountpoint,
                'fsType': partitions[0].fstype,
                'perms': partitions[0].opts,
                'totalSize': get_size(psutil.disk_usage(partitions[0].mountpoint).total),
                'used': get_size(psutil.disk_usage(partitions[0].mountpoint).used),
                'free': get_size(psutil.disk_usage(partitions[0].mountpoint).free),
                'used%': psutil.disk_usage(partitions[0].mountpoint).percent,
                },
         'partition1': {
                'device': partitions[1].device,
                'mountpoint': partitions[1].mountpoint,
                'fsType': partitions[1].fstype,
                'perms': partitions[1].opts,
                'totalSize': get_size(psutil.disk_usage(partitions[1].mountpoint).total),
                'used': get_size(psutil.disk_usage(partitions[1].mountpoint).used),
                'free': get_size(psutil.disk_usage(partitions[1].mountpoint).free),
                'used%': psutil.disk_usage(partitions[1].mountpoint).percent,
                },
          'partition3': {
                'device': partitions[2].device,
                'mountpoint': partitions[2].mountpoint,
                'fsType': partitions[2].fstype,
                'perms': partitions[2].opts,
                'totalSize': get_size(psutil.disk_usage(partitions[2].mountpoint).total),
                'used': get_size(psutil.disk_usage(partitions[2].mountpoint).used),
                'free': get_size(psutil.disk_usage(partitions[2].mountpoint).free),
                'used%': psutil.disk_usage(partitions[2].mountpoint).percent
                }
    },
    'network': {
    	'primaryInterface': nf.gateways().get('default').get(2)[1],
    	'privateIP': psutil.net_if_addrs().get(interface)[0].address,
    	'defaultGateway': nf.gateways().get('default').get(2)[0],
    	'publickIP': public_ip.text,
    	'RX_bytes': get_size(network_io.bytes_recv),
    	'TX_bytes': get_size(network_io.bytes_sent)
    }
}

#pp = pprint.PrettyPrinter(indent=3)

print(main)
