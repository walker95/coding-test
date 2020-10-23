#!/bin/bash
#Author: Amit
#Date Created: 20-Apr-2020
#Date Modified: 22-Apr-2020
#Description: check and start services in docker container by running once

changeDevicePerm() {
	echo ' ' | sudo -S chown -R sp:sp /dev/video0
	echo ' ' | sudo -S chmod 660 /dev/video0
}

startSupervisor() {
	echo ' ' | sudo -S service supervisor start
}

mongoStart() {
	echo ' ' | sudo -S service mongodb start
}

changeMongoPerm() {
	echo ' ' | sudo -S chown -R mongodb:mongodb /var/lib/mongodb/
}



devicePerm() {
	if [ $(stat -c '%U' /dev/video0) == "sp" ]
	then
		true
	else
		false
	fi
}

mongoPerm() {
	if [ $(stat -c '%U' /var/lib/mongodb/) == "mongodb" ]
	then
		true
	else
		false
	fi
}

mongoStat() {
	pgrep mongod >> /dev/null && true || false
}

supervisorStat() {
	pgrep supervisord >> /dev/null && true || false
}

start() {
	if devicePerm
	then
		if mongoPerm
		then
			if mongoStat
			then
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			else
				mongoStart
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			fi
		else
			changeMongoPerm
			if mongoStat
			then
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			else
				mongoStart
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			fi
		fi
	else
		changeDevicePerm
		if mongoPerm
		then
			if mongoStat
			then
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			else
				mongoStart
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			fi
		else
			changeMongoPerm
			if mongoStat
			then
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			else
				mongoStart
				if supervisorStat
				then
					echo everything is fine
				else
					startSupervisor
				fi
			fi
		fi
	fi
}
start

