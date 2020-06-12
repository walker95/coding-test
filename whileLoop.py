#!/usr/bin/python3

import os, time
from datetime import datetime

while True:
    now = datetime.now()
    if now.minute == 0:
        os.mkdir(now)

