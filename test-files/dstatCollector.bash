#!/bin/bash
#this is a dstat collector for linux

#collect per CPU Details for the current moment
dstat --cpu-use --output /tmp/dstatOut/per-cpu.csv 1 1
#internal:
#	
# 	aio, cpu, cpu-adv, cpu-use, cpu24, disk, disk24, disk24-old, epoch, fs, int, int24, io, ipc, load, lock, mem, mem-adv, net, page, 
# 	page24, proc, raw, socket, swap, swap-old, sys, tcp, time, udp, unix, vm, vm-adv, zones
# /usr/share/dstat:
	

# 	battery, battery-remain, condor-queue, cpufreq, dbus, disk-avgqu, disk-avgrq, disk-svctm, disk-tps, disk-util, disk-wait, dstat, 
# 	dstat-cpu, dstat-ctxt, dstat-mem, fan, freespace, fuse, gpfs, gpfs-ops, helloworld, innodb-buffer, innodb-io, innodb-ops, lustre, 
# 	md-status, memcache-hits, mysql-io, mysql-keys, mysql5-cmds, mysql5-conn, mysql5-innodb, mysql5-innodb-basic, mysql5-innodb-extra, 
# 	mysql5-io, mysql5-keys, net-packets, nfs3, nfs3-ops, nfsd3, nfsd3-ops, nfsd4-ops, nfsstat4, ntp, postfix, power, proc-count, qmail, 
# 	redis, rpc, rpcd, sendmail, snmp-cpu, snmp-load, snmp-mem, snmp-net, snmp-net-err, snmp-sys, snooze, squid, test, thermal, top-bio, 
# 	top-bio-adv, top-childwait, top-cpu, top-cpu-adv, top-cputime, top-cputime-avg, top-int, top-io, top-io-adv, top-latency, 
# 	top-latency-avg, top-mem, top-oom, utmp, vm-cpu, vm-mem, vm-mem-adv, vmk-hba, vmk-int, vmk-nic, vz-cpu, vz-io, vz-ubc, wifi, zfs-arc, 
# 	zfs-l2arc, zfs-zil