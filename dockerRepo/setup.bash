#!/bin/bash
diff='============================================='
echo "installing packages..."
apt update && apt install -y httpie tree
if [ -e "/usr/bin/docker" ]
then
	echo "checking docker version"
	docker version
	if [ -e "/usr/bin/docker-compose" ]
	then
		echo "checking docker-compose version"
		docker-compose version
		systemctl start docker
		systemctl enable docker
		echo "changing dir to /mnt"
		cd /mnt
		echo "creating dirs nginx & auth"
		mkdir -p registry/{nginx, auth}
		echo "creating dirs conf.d & ssl"
		mkdir -p registry/nginx/{conf.d/, ssl}
		echo "directory TREE"
		tree
		touch docker-compose.yml
		echo -e "$diff\nget docker-compose.yml file and place it here before proceeding...\n$diff"
		cd registry/nginx/conf.d/
		echo -e "$diff\nget registry.conf file and place it here befor proceeding...\n$diff"
		echo 'client_max_body_size 2G;' > additional.conf
		echo "$diff\ngenerate a ssl certificate for your domain name and place the files 'fullchain.pem' and 'privkey.pem' in 'ssl' directory..\n$diff"
		cd ../auth
		echo "$diff\ngenerating password for user administrator\n$diff"
		htpasswd -Bc registry.passwd administrator
		echo "$diff\nchanging dir to ../nginx/ssl\n$diff"
		cd ../nginx/ssl
		echo "$diff\ncreating rootCA.crt file\n$diff"
		openssl x509 -in fullchain.pem -inform PEM -out rootCA.crt
		mkdir -p /etc/docker/certs.d/your-domain.com/
		cp rootCA.crt /etc/docker/certs.d/your-domain.com/
		mkdir -p /usr/share/ca-certificates/extra/
		cp rootCA.crt /usr/share/ca-certificates/extra/
		dpkg-reconfigure ca-certificates
		systemctl restart docker
		echo "$diff\nNow run docker registry with docker-compose up -d\n$diff"
	else
		echo "install docker-compose first...."
	fi
else
	echo "install docker first....."
fi
