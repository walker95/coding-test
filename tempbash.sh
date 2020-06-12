#!/bin/bash

if [ $(stat -c '%U' /dev/video0) == "sp" ]
then
	echo ok
else
	echo not ok
fi
