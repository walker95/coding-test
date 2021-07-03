#!/usr/bin/env bash

install() {
	if [ "$(whoami)" == "root" ]
	then
		read -p "what version of postgresql you want to install?: " pgver
		ver=$(cat /etc/os-release | grep VERSION_CODENAME | cut -b 18-22)
		echo "running as root."
		if [ -e "/etc/apt/sources.list.d/pgdg.list" ]
		then
			#echo "deb http://apt.postgresql.org/pub/repos/apt/ $ver-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
			wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc |  apt-key add -
			apt update
			apt install -y postgresql-$pgver vim 
			echo " "
			echo -e  "run following commands to start the server....\n===pg_ctlcluster $pgver main start\nOR\n===/usr/lib/postgresql/$pgver/bin/postgres", "-D", "/etc/postgresql/$pgver/main"
		else
			echo "deb http://apt.postgresql.org/pub/repos/apt/ $ver-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
			install
		fi
	else
		echo "you need to be root to run this script..."
		sudo -i 
		install
	fi
	}


check() {
	if [ "$(cat /proc/1/cmdline)" != "/sbin/init" ]
	then
		echo "ruuning in a Docker container..."
		apt update && apt upgrade -y && apt install -y gnupg tzdata wget vim  && install
	else
		echo "ruuning on a host system..."
		install
	fi
}

check



