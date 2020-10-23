#!/bin/bash
ping -c 2 $1 | grep 64 >> /dev/null && live='True'
if [ "$live" == "True" ]
then
	echo "IP $1 is live"
	nc -vz $1 22 && connect='True'
	if [ "$connect" == "True" ]
	then
		echo "============================================================================================="
		ssh $1 "echo $HOSTNAME && echo "available services: " && for i in ssh postgres mysql mongo redis; do ps -A | grep $i >> /dev/null && echo $i || echo "$i not found"; done"
		ssh $1 "netstat -lntup | grep "0.0.0.0\|127.0.0.1" | awk '{print $4,$7}'"
		nmap -O $1
	else
		echo "unable to connect to ip $1 on port 22"
	fi
else
	echo "IP $1 is not live"
fi



echo scanning for openPorts
ssh $host "netstat -lntup | grep "0.0.0.0\|127.0.0.1" | awk '{print $4,$7}'"
echo scanning for services
ssh $host "dpkg -l | grep 'mysql\|postgres\|redis\|mongo' | awk '{print $2}'"

for i in ssh postgres mysql mongo redis; do ps -A | grep $i >> /dev/null && echo $i || echo "$i not found"; done