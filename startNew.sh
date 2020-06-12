#!/bin/bash
#Author: Amit
#Date Created: 20-Apr-2020
#Date Modified: 21-Apr-2020
#Description: check and start services in docker container by running once

devicePerm() {
	if [ $(stat -c '%U' /dev/video0) == "sp" ]
	then
		echo "device status is OK"
		true
	else
		echo ' ' | sudo -S chown -R sp:sp /dev/video0
		echo ' ' | sudo -S chmod 660 /dev/video0
		devicePerm
	fi
}

supervisorStart() {
	pgrep supervisord >> /dev/null 
	if [ $? -eq 0 ]
	then
		echo "everything is fine" 
	else
		echo ' ' | sudo -S service supervisor start
		supervisorStart
	fi
}

mongoStart() {
	pgrep mongod >> /dev/null
        if [ $? -eq 0 ]
	then
		echo "mongo is running"
		true 
	else
		echo ' ' | sudo -S service mongodb start
		mongoStart
	fi
}

mongoPerm() {
	stat -c '%U' /var/lib/mongodb | grep mongodb >> /dev/null
	if [ $? -eq 0 ]
	then
		echo "mongo permission is OK"
		true
	else
		if [ -e /tmp/mongodb-27017.sock ]
		then
			echo ' ' | sudo -S rm /tmp/mongodb-27017.sock
		fi
		echo ' ' | sudo -S chown -R mongodb:mongodb /var/lib/mongodb
		mongoPerm
	fi	
}

start() {
	if devicePerm
	then
		if mongoPerm
		then
			if mongoStart
			then
				supervisorStart
			fi
		fi
	fi
}

start
				



