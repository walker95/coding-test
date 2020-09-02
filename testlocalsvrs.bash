#/bin/bash

for i in {1..254}
do
	ping -c 2 10.10.12.$i | grep 64 >> /dev/null
	if [ $? -eq 0 ]
	then
		nmap --host-timeout 1m 10.10.12.$i -v
	else
		echo IP 10.10.12.$i is not live
	fi
done
