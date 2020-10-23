#!/bin/bash
#Author: Amit Kumar Singh
#date created: 06-Oct-2020
#date modified: 06-Oct-2020
#Note: changes ${args}.sql ==> ${args}
#description: automatic backup of postgres databases
line="============================================================="
main () {
	if [ -d ~/dbbackup ]
	then
		echo -e "${line}\nswitching directory to ~/dbbackup\n${line}"
		cd ~/dbbackup
		if [[ "${HOSTNAME}" =~ ^tst ]]
		then
			echo -e "${line}\nrunning on ${HOSTNAME}\n${line}"
			dump ${HOSTNAME}
		elif [[ "${HOSTNAME}" =~ ^SP ]]
		then
			echo -e "${line}\nrunning on ${HOSTNAME}\n${line}"
			dump mirrors-pg bg-sgp-global bb-psql
		else
			echo -e "${line}\nbad Host. Exiting.....Try again\n${line}"
		fi
	else
		echo -e "${line}directory ~/dbbackup dosen't exists. creating....\n${line}"
		mkdir ~/dbbackup
		main
	fi
}

dump() {
	for args in $@
	do
		if [ -f .${args} ]
		then
			source ./.${args}
			echo -e "${line}\nDumping starts @ \n\t$(date)\n${line}"
			pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDB -F p >> ${args}.sql && dump='complete' || echo -e '${line}\nDump failed. There might be some errors. Check and fix.\n${line}'
			#pg_dump -h $PGHOST -p $PGPORT -U $PGUSER $PGDB -F tar | pigz > bg-sgp-global.tar.gz >> tar.log
			echo -e "${line}\ndumping done. Compressing...\n${line}"
			sleep 10
			compress ${args}.sql
		else
			echo -e "${line}\nenvironment variable file ${args} dosen't exists. Please create the file and Try again\n${line}"
		fi
	done
}

compress() {
	if [ -f $1 ]
		then
			if [ "$dump" == "complete" ]
			then
				dtm=$(date +"%Y%m%d_%H%M")
				echo -e "${line}\ncompression starts....@ \n\t$(date)\n${line}"
				# tar -cvf $1.$dt.tar.xz --use-compress-program='xz -7T3' $1 && compress="True"
				# tar -I pxz -cf $1.$dtm.txz $1 && compress='True'
				tar --use-compress-program='pigz -k' -cf $1.${dtm}.tgz $1 && compress='True'
				echo -e "${line}\ncompression done....@ $(date). copying\n${line}"
				copy_and_delete $1.${dtm}.tgz
			else
				echo -e "${line}\nDump failed. Please Try again\n${line}"
			fi
	else
		echo -e "${line}\n$1 not available. Not archiving\n${line}"
	fi
}

copy_and_delete() {
	#copy using s3cmd
	if [ -f $1 ]
	then
		if [ "$compress" == "True" ]
		then
			echo -e "${line}\ncompression done. Copying to spaces\n${line}"
			s3cmd put s3://$1/ && copied='True'
			sleep 10
			#delete the file upon successfull copying...
			if [ "$copied" == "True" ]
			then
				echo -e "${line}\ncopied to spaces. Deleting...\n${line}"
				rm $1
			else
				echo -e "${line}\nIt seems copying wasn't successfull. Aborting. Check and fix...\n${line}"
			fi
		else
			echo -e "${line}\nit seems compression wasn't successfull. Aborting. Check and fix...\n${line}"
		fi
	else
		echo -e "${line}\nfile ${args} isn't available. Please check and try again\n${line}"
	fi
 }

main






