#!/usr/bin/python3
#About: This will be a Flask App that returns data against the system
#prerequisits: python3,venv(psutil), statgrab
import os, time, json
import psutil
cmd = 'statgrab -o > statgrab.txt'
exec = os.system(cmd)
infile = 'statgrab.txt'
outfile = 'statgrab.json'
statdict = {}
def modifyStat(infile):
    if exec == 0:
        if os.path.isfile(infile):
            print(f"command executed and file {file} created")
            with open(infile) as inFile:
                for line in inFile:
                    line = line.strip().split('=')
                    statdict[f"{line[0]}"] = f"{line[1]}"
                    with open(outfile, 'w') as outFile:
                    	json.dumps(statedict, outFile)
    return statedict

modifyStat(statgrab.text)



