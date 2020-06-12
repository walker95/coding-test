#!/bin/bash

while sleep 5
do
	pgrep mongod && rat=0
	if [ $rat -eq 0 ]
	then
		pgrep supervisord && rat=0
		if [ $rat -eq 0 ]
		then
			echo "everything is fine"
		else
			/etc/init.d/supervisor start
		fi
	else
		/etc/init.d/mongodb start
	fi
	echo "" 
done