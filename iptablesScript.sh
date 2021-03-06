#!/bin/sh
#
# firewall      Firewall startup/shutdown script
#
# Version:      @(#) /etc/init.d/firewall.iptables  01-August-2010
#
#
# Translated to iptables format, with many additions and modifications,
# from Craig Zeller's (zeller@fatpenguin.com) ipchains-based firewall script, by
# Bob Sully (rcs@malibyte.net)
#
# Thanks to Jeff Carlson (jeff@ultimateevil.org) for his assistance re: DHCP and several other issues, 
# Rohan Amin (rohan@rohanamin.com) and Erik Wasser (erik.wasser@iquer.com) for help with the port-forwarding 
# routine, and Chris Fincham for his work on the PPTP client routine.

#
# Latest revision: 01-August-2010
#

# chkconfig: 345 11 91
#
# description: IP Firewall startup/shutdown script for iptables
#
# probe: true
#

#
# CONSTANTS - Do not edit
#

ANYWHERE="0.0.0.0/0"			# Match any IP address
BROADCAST_SRC="0.0.0.0"			# Broadcast Source Address
BROADCAST_DEST="255.255.255.255"	# Broadcast Destination Address
CLASS_A="10.0.0.0/8"			# Class-A Private (RFC-1918) Networks
CLASS_B="172.16.0.0/12"			# Class-B Private (RFC-1918) Networks
CLASS_C="192.168.0.0/16"		# Class-C Private (RFC-1918) Networks
CLASS_D_MULTICAST="224.0.0.0/4"		# Class-D Multicast Addresses
CLASS_E_RESERVED_NET="240.0.0.0/5"	# Class-E Reserved Addresses
PRIVPORTS="0:1023"			# Well-Known, Privileged Port Range
UNPRIVPORTS="1024:65535"		# Unprivileged Port Range
TRACEROUTE_SRC_PORTS="32769:65535"	# Traceroute Source Ports
TRACEROUTE_DEST_PORTS="33434:33523"	# Traceroute Destination Ports


#
# The Loopback interface defines should not be
# edited unless your Linux distribution defines
# these differently.
#

LOOPBACK_INTERFACE="lo"			# The loopback interface
LOOPBACK_NETWORK="127.0.0.0/8"		# Reserved Loopback Address Range

#######################################################################
#								      #
# Notes for those running Debian or its derivatives (Ubuntu, etc.):   #
#								      #
# (1) Delete or comment out the following lines:		      #
#								      #
##								      #
## Source function library.					      #
##								      #
# . /etc/rc.d/init.d/functions					      #
#								      #
# (2) As root, mkdir /var/lock/subsys				      #
#								      #
#######################################################################


##
## Source function library.
##
#. /etc/rc.d/init.d/functions


#
# See how we were called.
#

case "$1" in
  start)
        echo "Starting Firewall services"
	echo "firewall: Configuring Firewall Rules using iptables"

 	# Remove any existing rules from all chains
    	iptables -F
    	iptables -F -t nat
    	iptables -F -t mangle

    	# Remove any pre-existing user-defined chains
    	iptables -X
    	iptables -X -t nat
    	iptables -X -t mangle

	# Zero counts
	iptables -Z

    	# Set the default policy to drop
    	iptables -P INPUT   DROP
    	iptables -P OUTPUT  DROP
    	iptables -P FORWARD DROP

	# Allow unlimited traffic on the loopback interface
	iptables -A INPUT -i $LOOPBACK_INTERFACE -j ACCEPT
	iptables -A OUTPUT -o $LOOPBACK_INTERFACE -j ACCEPT

	# A bug that showed up as of the Red Hat 7.2 release results in
    	# the following 5 default policies breaking the firewall
    	# initialization:

	#     fgrep -q '7.2' /etc/redhat-release
	#     if [ $? -ne 0 ] ; then
	#       iptables -t nat    -P PREROUTING  DROP
	#       iptables -t nat    -P OUTPUT      DROP 
	#       iptables -t nat    -P POSTROUTING DROP

	#       iptables -t mangle -P PREROUTING  DROP
	#       iptables -t mangle -P OUTPUT      DROP
	#     fi


	# Open the configuration file
	if [ -f /etc/firewall/firewall.conf.iptables ]; then
	    . /etc/firewall/firewall.conf.iptables
	else
	    # Turn off IP Forwarding & Masquerading
	    echo 0 >/proc/sys/net/ipv4/ip_forward
	
	    # Turn off dynamic IP hacking
            echo "0" > /proc/sys/net/ipv4/ip_dynaddr
	
	    echo "firewall: No configuration file found at /etc/firewall/firewall.conf.iptables; "
	    echo "firewall: default policies set to DROP on INPUT/OUTPUT/FORWARD chains."
	    exit 1
	fi


        #
        # If your IP address is dynamically assigned by a DHCP server,
        # your DHCP server's IP address and this machine's IP address are
        # obtained from /etc/dhcpc/hostinfo-$EXTERNAL_INTERFACE or
        # /etc/dhcpc/dhcpcd-$EXTERNAL_INTERFACE.info.
        #


        if [ $DHCP -gt 0 ]; then

	  # Grab external IP address if already assigned

          EXTERNAL_IP=$( ifconfig $EXTERNAL_INTERFACE | grep 'inet[^6]' | sed 's/[a-zA-Z:]//g' | awk '{print $1}' )
	  if [ -n $EXTERNAL_IP ]; then
            EXT_NETMASK=$( ifconfig $EXTERNAL_INTERFACE | grep 'inet[^6]' | sed 's/[a-zA-Z:]//g' | awk '{print $3}' ) 

        # For RedHat, Mandrake, etc.
	   #EXTERNAL_NETWORK=$( ipcalc -n $EXTERNAL_IP $EXT_NETMASK | cut -d\= -f2 )
	   #BROADCAST_NET=$( ipcalc -b $EXTERNAL_IP $EXT_NETMASK | cut -d\= -f2 )
        # For Debian/Ubuntu, etc.:
            EXTERNAL_NETWORK=$( ipcalc -n $EXTERNAL_IP $EXT_NETMASK | grep Network | sed 's/\/[0-9].*//g' | awk '{print $2}' )
            BROADCAST_NET=$( ifconfig $EXTERNAL_INTERFACE | grep 'inet[^6]' | sed 's/[a-zA-Z:]//g' | awk '{print $2}' )
	  fi 

          # Turn on dynamic IP hacking
          echo "1" > /proc/sys/net/ipv4/ip_dynaddr


          # Incoming DHCPOFFER from available DHCP servers
          iptables -A INPUT -i $EXTERNAL_INTERFACE -p udp \
                   -s 0.0.0.0         --sport 67 \
                   -d 255.255.255.255 --dport 68 -j ACCEPT

          # Initialization of rebinding: No lease or Lease time expired.
          iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p udp   \
                   -s 0.0.0.0         --sport 68 \
                   -d 255.255.255.255 --dport 67 -j ACCEPT

          # Fall back to initialization
          # The client knows its server, but has either lost its
          # lease, or else needs to reconfirm the IP address after
          # rebooting.
          iptables -A INPUT -i $EXTERNAL_INTERFACE -p udp \
                   -s $DHCP_SERVER_IP --sport 67     \
                   -d 255.255.255.255 --dport 68 -j ACCEPT
          iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p udp \
                   -s 255.255.255.255 --sport 68 \
                   -d $DHCP_SERVER_IP --dport 67 -j ACCEPT

          # As a result of the above, we're supposed to change our IP
          # address with this message, which is addressed to our new
          # address before the dhcp client has received the update.
          # Depending on the server implementation, the destination
          # address can be the new IP address, the subnet address, or
          # the limited broadcast address.

          # If the network subnet address is used as the destination,
          # the next rule must allow incoming packets destined to the
          # subnet address, and the rule must preceed any general rules
          # that block such incoming broadcast packets.

          iptables -A INPUT -i $EXTERNAL_INTERFACE -p udp \
                   -s $DHCP_SERVER_IP --sport 67     \
                   --dport 68 -j ACCEPT

          # Lease renewal
          iptables -A INPUT -i $EXTERNAL_INTERFACE -p udp \
                   -s $DHCP_SERVER_IP --sport 67     \
                   -d $EXTERNAL_IP --dport 68 -j ACCEPT
          iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p udp \
                   -s $EXTERNAL_IP --sport 68       \
                   -d $DHCP_SERVER_IP --dport 67 -j ACCEPT

          echo "firewall: DHCP Client configured"
	  
	  else
	    # External IP assigned without DHCP (i.e. static); get netmask
            EXT_NETMASK=$( ifconfig $EXTERNAL_INTERFACE | grep 'inet[^6]' | sed 's/[a-zA-Z:]//g' | awk '{print $3}' )
	  
        fi


	#
  	# Refuse directed broadcasts; you may choose not to log these, as they can fill up your logs quickly
	#

#   	iptables -A INPUT -i $EXTERNAL_INTERFACE -d $EXTERNAL_NETWORK \
#             -m limit --limit 1/s            \
#             -j LOG --log-prefix "[Directed Broadcast] "
    	iptables -A INPUT -i $EXTERNAL_INTERFACE -d $EXTERNAL_NETWORK -j DROP
# 	iptables -A INPUT -i $EXTERNAL_INTERFACE -d $BROADCAST_NET \
#             -m limit --limit 1/s            \
#             -j LOG --log-prefix "[Directed Broadcast] "
	iptables -A INPUT  -i $EXTERNAL_INTERFACE -d $BROADCAST_NET -j DROP

	# Refuse limited broadcasts
#    	iptables -A INPUT  -i $EXTERNAL_INTERFACE -d 255.255.255.255 \
#             -m limit --limit 1/s                    \
#             -j LOG --log-prefix "[Limited Broadcast] "
    	iptables -A INPUT  -i $EXTERNAL_INTERFACE -d 255.255.255.255 -j DROP



	#
	# Edit these to match the number of servers or connections
	# you support.
	#

	# X Window port allocation begins at 6000 and increments
	# for each additional server running from 6000 to 6063.

	XWINDOW_PORTS="6000:6063"		# (TCP) X Windows

	# SSH starts at 1023 and works down to 513 for each additional
	# simultaneous incoming connection.

	SSH_HI_PORTS="513:1023"			# SSH Simultaneous Connections


	#
	# Iptables allows creation of customized chains.  The -l (log) flag no longer
	# exists.  This is a custom chain which allows logging of DROPped packets.
	#

	iptables -N LnD			# Define custom DROP chain

	iptables -A LnD -p tcp -m limit --limit 1/s -j LOG --log-prefix "[TCP drop] " --log-level=info
	iptables -A LnD -p udp -m limit --limit 1/s -j LOG --log-prefix "[UDP drop] " --log-level=info
	iptables -A LnD -p icmp -m limit --limit 1/s -j LOG --log-prefix "[ICMP drop] " --log-level=info
	iptables -A LnD -f -m limit --limit 1/s -j LOG --log-prefix "[FRAG drop] " --log-level=info
	iptables -A LnD -j DROP

	#
	# This custom chain logs, then REJECTs packets.
	#

	iptables -N LnR			# Define custom REJECT chain

	iptables -A LnR -p tcp -m limit --limit 1/s -j LOG --log-prefix "[TCP reject] " --log-level=info
	iptables -A LnR -p udp -m limit --limit 1/s -j LOG --log-prefix "[UDP reject] " --log-level=info
	iptables -A LnR -p icmp -m limit --limit 1/s -j LOG --log-prefix "[ICMP reject] " --log-level=info
 	iptables -A LnR -f -m limit --limit 1/s -j LOG --log-prefix "[FRAG reject] " --log-level=info
	iptables -A LnR -j REJECT

	#
	# This chain logs, then DROPs "Xmas" and Null packets which might indicate a port-scan attempt
	#

	iptables -N ScanD		# Define custom chain for possible port-scans

	iptables -A ScanD -p tcp -m limit --limit 1/s -j LOG --log-prefix "[TCP Scan?] "
	iptables -A ScanD -p udp -m limit --limit 1/s -j LOG --log-prefix "[UDP Scan?] "
	iptables -A ScanD -p icmp -m limit --limit 1/s -j LOG --log-prefix "[ICMP Scan?] "
	iptables -A ScanD -f -m limit --limit 1/s -j LOG --log-prefix "[FRAG Scan?] "
	iptables -A ScanD -j DROP


	#
        # This chain limits the number of new incoming connections to limit the effectiveness of DDoS attacks
        #
                                                                                                                  
        iptables -N DDoS                # Define custom chain for possible DDoS attack or SYN-flood scan
                                                                                                                  
        iptables -A DDoS -m limit --limit 1/s --limit-burst 10 -j RETURN
	# Comment the next line out if you don't want to fill up your logs with these.
	#iptables -A DDoS -j LOG --log-prefix "[DOS Attack/SYN Scan?] "
	iptables -A DDoS -j DROP


       # ipv6 traffic - allows ONLY icmp and established/related and loopback traffic on ipv6
        ip6tables -A INPUT -i $LOOPBACK_INTERFACE -j ACCEPT
        ip6tables -A INPUT -p icmpv6 -i $EXTERNAL_INTERFACE -j ACCEPT
        ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        ip6tables -A INPUT -j DROP
	echo "firewall: allowing ONLY icmp and established/related and loopback traffic on ipv6"


	#
        # This chain drops connections from IANA reserved IP blocks
        #

	iptables -N IANA	

	iptables -A IANA -p tcp -m limit --limit 1/s -j LOG --log-prefix "[IANA Reserved - TCP] " --log-level=info
	iptables -A IANA -p udp -m limit --limit 1/s -j LOG --log-prefix "[IANA Reserved - UDP] " --log-level=info
	iptables -A IANA -p icmp -m limit --limit 1/s -j LOG --log-prefix "[IANA Reserved - ICMP] " --log-level=info
	iptables -A IANA -f -m limit --limit 1/s -j LOG --log-prefix "[IANA Reserved - FRAG] " --log-level=info
	iptables -A IANA -j DROP


	#
        # This chain drops connections from IPs in the firewall.banned file
        #

	iptables -N Banned	

	iptables -A Banned -p tcp -m limit --limit 1/s -j LOG --log-prefix "[TCP Banned] " --log-level=info
	iptables -A Banned -p udp -m limit --limit 1/s -j LOG --log-prefix "[UDP Banned] " --log-level=info
	iptables -A Banned -p icmp -m limit --limit 1/s -j LOG --log-prefix "[ICMP Banned] " --log-level=info
	iptables -A Banned -f -m limit --limit 1/s -j LOG --log-prefix "[FRAG Banned] " --log-level=info
	iptables -A Banned -j DROP


        #
        # Disallow packets frequently used by port-scanners
        # 

	# All of the bits are cleared
    	iptables -A INPUT -p tcp --tcp-flags ALL NONE -j ScanD

    	# SYN and FIN are both set
    	iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j ScanD

    	# SYN and RST are both set
    	iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j ScanD

    	# FIN and RST are both set
    	iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j ScanD

    	# FIN is the only bit set, without the expected accompanying ACK
    	iptables -A INPUT -p tcp --tcp-flags ACK,FIN FIN -j ScanD

    	# PSH is the only bit set, without the expected accompanying ACK
    	iptables -A INPUT -p tcp --tcp-flags ACK,PSH PSH -j ScanD

    	# URG is the only bit set, without the expected accompanying ACK
    	iptables -A INPUT -p tcp --tcp-flags ACK,URG URG -j ScanD

	# SYN-Flood 
	# (Request for new connection; large number indicate possible DDoS-type attack; same as --syn)
	iptables -A INPUT -p tcp --tcp-flags SYN,RST,ACK SYN -j DDoS


	# Enable broadcast echo Protection
	echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

	# Disable Source Routed Packets
	for f in /proc/sys/net/ipv4/conf/*/accept_source_route; do
    	   echo 0 > $f
	done

	# Enable TCP SYN Cookie Protection
	echo 1 > /proc/sys/net/ipv4/tcp_syncookies

	# Disable ICMP Redirect Acceptance
	for f in /proc/sys/net/ipv4/conf/*/accept_redirects; do
   	   echo 0 > $f
	done

	# Don't send Redirect Messages
	for f in /proc/sys/net/ipv4/conf/*/send_redirects; do
   	   echo 0 > $f
	done

	# Disable ICMP Redirect Acceptance
	for f in /proc/sys/net/ipv4/conf/*/accept_redirects; do
	    echo 0 > $f
	done

	# Drop Spoofed Packets coming in on an interface, which if replied to,
	# would result in the reply going out a different interface.
	for f in /proc/sys/net/ipv4/conf/*/rp_filter; do
  	   echo 1 > $f
	done

	# Log packets with impossible addresses.
	for f in /proc/sys/net/ipv4/conf/*/log_martians; do
  	   echo 1 > $f
	done


	# Disallow fragmented packets.  This may not be as necessary as it once was.
	# Comment it out with # if desired.
	#  iptables -A INPUT -f -i $EXTERNAL_INTERFACE -j LnD
	#  iptables -A INPUT -f -i $INTERNAL_INTERFACE -j LnD


	#
	# Loopback
	#

	# Unlimited traffic on the loopback interface (lo)

	iptables -A INPUT -i $LOOPBACK_INTERFACE -j ACCEPT
	iptables -A OUTPUT -o $LOOPBACK_INTERFACE -j ACCEPT


	#
	# Refuse any connections to/from problem sites.
	#
	# /etc/firewall/firewall.banned contains a list of IPs
	# to block all access, both inbound and outbound.
	# The file should contain IP addresses with CIDR
	# netmask, one per line:
	#
	# NOTE: No comments are allowed in the file.
	#
	# 111.0.0.0/8			- To block a Class-A network
	# 111.222.0.0/16		- To block a Class-B network
	# 111.222.254.0/24		- To block a Class-C network
	# 111.222.254.244/32		- To block a single IP address
	#
	# The CIDR netmask number describes the number of bits
	# in the network portion of the address, and may be on
	# any boundary.
	#

	if [ -f /etc/firewall/firewall.banned ]; then
	    while read BANNED; do
		iptables -A INPUT -i $EXTERNAL_INTERFACE -s $BANNED -j Banned
		iptables -A INPUT -i $EXTERNAL_INTERFACE -d $BANNED -j Banned
		iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $BANNED -j Banned
		iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $BANNED -j Banned
		iptables -A FORWARD -d $BANNED -j Banned
                iptables -A FORWARD -s $BANNED -j Banned
	    done < /etc/firewall/firewall.banned
	    echo "firewall: Banned addresses added to rule set"
	
	else
	    echo "firewall: Banned address/network file not found."
	fi

	#
	# Refuse connections from IANA-reserved blocks
	#
	
	if [ -f /etc/firewall/firewall.iana-reserved ]; then
	    while read RESERVED; do
		iptables -A INPUT -i $EXTERNAL_INTERFACE -s $RESERVED -j IANA
		iptables -A INPUT -i $EXTERNAL_INTERFACE -d $RESERVED -j IANA
		iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $RESERVED -j IANA
		iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $RESERVED -j IANA
	    done < /etc/firewall/firewall.iana-reserved
	    echo "firewall: Connections from IANA-reserved addresses blocked"

	else
	    echo "firewall: IANA-reserved address/network file not found."
	fi

	#
	# Localizations
	#
	# The /etc/firewall/firewall.local file should contain rules in
	# standard 'iptables' format.
	#

	if [ -f /etc/firewall/firewall.local.iptables ]; then
	    . /etc/firewall/firewall.local.iptables
	    echo "firewall: Local rules added"
	else
	    echo "firewall: Local rules file not found."
	fi


	#
	# ICMP
	#

	# (4) Source Quench.
	# Incoming & outgoing requests to slow down (flow control)

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p ICMP --icmp-type 4 \
	    -s $ANYWHERE  -d $EXTERNAL_IP -j ACCEPT

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP --icmp-type 4 \
	    -s $EXTERNAL_IP  -d $ANYWHERE -j ACCEPT

	if [ $MASQUERADING -gt 0 ]; then
	    iptables -A FORWARD -p ICMP --icmp-type 4 -j ACCEPT
	fi

	# (12) Parameter Problem.
	# Incoming & outgoing error messages

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p ICMP --icmp-type 12 \
	    -s $ANYWHERE  -d $EXTERNAL_IP -j ACCEPT

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP --icmp-type 12 \
	    -s $EXTERNAL_IP  -d $ANYWHERE -j ACCEPT

	if [ $MASQUERADING -gt 0 ]; then
	    iptables -A FORWARD -p ICMP --icmp-type 12 -j ACCEPT
	fi

	# (3) Destination Unreachable, Service Unavailable.
	# Incoming & outgoing size negotiation, service or
	# destination unavailability, final traceroute response

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p ICMP --icmp-type 3 \
	    -s $ANYWHERE  -d $EXTERNAL_IP -j ACCEPT

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP --icmp-type 3 \
	    -s $EXTERNAL_IP  -d $ANYWHERE -j ACCEPT

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP --icmp-type \
	    fragmentation-needed -s $EXTERNAL_IP  -d $ANYWHERE -j ACCEPT

	if [ $MASQUERADING -gt 0 ]; then
	    iptables -A FORWARD -p ICMP --icmp-type 3 -j ACCEPT
	    iptables -A FORWARD -p ICMP --icmp-type fragmentation-needed -j ACCEPT
	fi

	# (11) Time Exceeded.
	# Incoming & outgoing timeout conditions,
	# also intermediate TTL response to traceroutes

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p ICMP --icmp-type 11 \
	    -s $ANYWHERE  -d $EXTERNAL_IP -j ACCEPT

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP --icmp-type 11 \
	    -s $EXTERNAL_IP  -d $ANYWHERE -j ACCEPT

	if [ $MASQUERADING -gt 0 ]; then
	    iptables -A FORWARD -p ICMP --icmp-type 11 -j ACCEPT
	fi

	# (0 | 8) Allow OUTPUT pings to anywhere.

	if [ $OUTBOUND_PING -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP --icmp-type 8 \
		-s $EXTERNAL_IP  -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p ICMP --icmp-type 0 \
		-s $ANYWHERE  -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p ICMP --icmp-type 8 -s $INTERNAL_NETWORK -j ACCEPT
	       iptables -A FORWARD -p ICMP --icmp-type 0 -d $INTERNAL_NETWORK -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Outbound ping enabled"
	    fi

	fi

	# (0 | 8) Allow incoming pings from anywhere
	#       (stops at firewall).

	if [ $INBOUND_PING -gt 0 ]; then

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p ICMP --icmp-type 8 \
		-s $ANYWHERE  -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP --icmp-type 0 \
		-s $EXTERNAL_IP  -d $ANYWHERE -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Inbound ping enabled"
	    fi

	fi

	#
	# Unprivileged Ports
	# Avoid ports subject to protocol and system administration problems.
	#

	NFS_PORT="2049"				# (TCP/UDP) NFS
	OPENWINDOWS_PORT="2000"			# (TCP) Openwindows
	SOCKS_PORT="1080"			# (TCP) Socks


	# Openwindows: establishing a connection

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport $OPENWINDOWS_PORT -s $EXTERNAL_IP -d $ANYWHERE -j LnR

	# Openwindows: incoming connection

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport $OPENWINDOWS_PORT -d $EXTERNAL_IP -j LnD

	# X Window: establishing a remote connection

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport $XWINDOW_PORTS -s $EXTERNAL_IP -d $ANYWHERE -j LnR

	# X Window: incoming connection attempt

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport $XWINDOW_PORTS -d $EXTERNAL_IP -j LnD

	# SOCKS: establishing a connection

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport $SOCKS_PORT -s $EXTERNAL_IP -d $ANYWHERE  -j LnR

	# SOCKS: incoming connection

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport	$SOCKS_PORT -d $EXTERNAL_IP -j LnD

	# NFS: TCP connections

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport $NFS_PORT -d $EXTERNAL_IP -j LnD

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
	--dport	$NFS_PORT -d $ANYWHERE -j LnR

	# NFS: UDP connections

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	--dport $NFS_PORT -d $EXTERNAL_IP -j LnD

	# NFS: incoming request (normal UDP mode)

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	--dport $NFS_PORT -d $ANYWHERE -j LnR


        #
        # DNAT/SNAT Port Forwarding
        # 

 	if [ $PORT_FORWARD -gt 0 ]; then 
           if [ -f /etc/firewall/firewall.nat ]; then
             while read IP_PORT; do
               # extract the protocols, IPs and ports
	       NAT_TYPE=$(echo "$IP_PORT" | awk '{print $1}')
               NAT_EXT_PORT=$(echo "$IP_PORT" | awk '{print $2}')
               NAT_INT_IP=$(echo "$IP_PORT" | awk '{print $3}')
               NAT_INT_PORT=$(echo "$IP_PORT" | awk '{print $4}')

               # write the rules!

               # this is the prerouting dnat
               iptables -A PREROUTING -t nat -p $NAT_TYPE -d $EXTERNAL_IP --dport $NAT_EXT_PORT -j DNAT \
                --to-destination $NAT_INT_IP:$NAT_INT_PORT

               # This allows packets from external->internal
               iptables -A FORWARD -i $EXTERNAL_INTERFACE -o $INTERNAL_INTERFACE -p $NAT_TYPE  \
                -d $NAT_INT_IP --dport $NAT_INT_PORT -m state \
                --state NEW,ESTABLISHED,RELATED -j ACCEPT

               # This allows packets from internal->external
               iptables -A FORWARD -i $INTERNAL_INTERFACE -o $EXTERNAL_INTERFACE -p $NAT_TYPE  \
                -s $NAT_INT_IP --sport $NAT_INT_PORT -m state \
                --state NEW,ESTABLISHED,RELATED -j ACCEPT

               # This enables access to the 'public' server from the internal network
               iptables -t nat -A POSTROUTING -d $NAT_INT_IP -s $INTERNAL_NETWORK \
                -p $NAT_TYPE --dport $NAT_INT_PORT -j SNAT --to $INTERNAL_IP

               echo firewall: dnat: $NAT_TYPE:$EXTERNAL_IP:$NAT_EXT_PORT - $NAT_INT_IP:$NAT_INT_PORT

             done < /etc/firewall/firewall.nat

            # unset some variables
              unset IP_PORT
	      unset NAT_TYPE
              unset NAT_EXT_PORT
              unset NAT_INT_IP
              unset NAT_INT_PORT

	   else
              echo "firewall.nat (port-forwarding table) not found!  Port-forwarding not enabled."
	   fi
        fi


	#
	# NOTE:
	#     The symbolic names used in /etc/services for the port numbers
	#     vary by supplier.
	#

	# Required Services

	#
	# DNS client modes (53)
	#

	if [ $DNS_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
		--sport $UNPRIVPORTS --dport 53 -s $EXTERNAL_IP \
		-d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -m state --state ESTABLISHED,RELATED -p UDP --sport 53 \
		--dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p UDP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 53 -j ACCEPT
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK --sport 53 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    # TCP client-to-server requests are allowed by the protocol
	    # if UDP requests fail. This is rarely seen. Usually, clients
	    # use TCP as a secondary name server for zone transfers from
	    # their primary name servers, and as hackers.

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP --sport \
		$UNPRIVPORTS --dport 53 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
		--sport 53 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 53 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 53 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: DNS client enabled"
	    fi
	fi

	#
	# DNS server modes (53)
	#

	#
	# DNS caching & forwarding name server
	#

	if [ $DNS_CACHING_SERVER -gt 0 ]; then

	    # Server-to-server query or response
	    # Caching only name server uses UDP, not TCP

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	--sport 53 --dport 53 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	--sport 53 --dport 53 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: DNS Caching server enabled"
	    fi

	fi

	#
	# DNS full name server
	#

	if [ $DNS_FULL_SERVER -gt 0 ]; then

	    # Client-to-server DNS transaction.

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	--sport $UNPRIVPORTS --dport 53 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	--sport 53 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
        --sport 53 --dport 53 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
        --sport 53 --dport 53 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT


	    # Zone Transfers.
	    # Due to the potential danger of zone transfers,
	    # allow TCP traffic to only specific secondaries.

            # /etc/firewall/firewall.dns contains a list of
            # secondary, tertiary, etc. domain name servers with which
            # zone transfers are allowed.  The file should contain IP
            # addresses with CIDR netmask, one per line:


        if [ -f /etc/firewall/firewall.dns ]; then
                while read DNS_SECONDARY; do

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
                --sport $UNPRIVPORTS --dport 53 -s $DNS_SECONDARY -d $EXTERNAL_IP -j ACCEPT

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
                --sport 53 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $DNS_SECONDARY -j ACCEPT

            done < /etc/firewall/firewall.dns

        else
            echo "firewall: ** No secondary DNS configured **"

        fi

            if [ $VERBOSE -gt 0 ]; then
                echo "firewall: DNS Full server enabled"
            fi

        fi

	#
	# AUTH (113) - Allowing your outgoing AUTH requests as a client
	#

	if [ $AUTH_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 113 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 113 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 113 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 113 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Auth client enabled"
	    fi

	fi


	# AUTH server (113)

	if [ $AUTH_SERVER -gt 0 ]; then

	    # Accepting incoming AUTH requests

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 113 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 113 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Auth server enabled"
	    fi

	else

	    # Rejecting incoming AUTH requests

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
		--dport 113 -d $EXTERNAL_IP -j LnR

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Auth server requests will be rejected"
	    fi

	fi


	#
	# TCP Services on selected ports.
	#

	#
	# Sending Mail through a remote SMTP server (25)
	#

	if [ $SMTP_REMOTE_SERVER -gt 0 ]; then

	   # SMTP client to an ISP account without a local server
	   for SMTP_SRVR in ${SMTP_SERVER}; do
 	
	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 25 -s $EXTERNAL_IP -d $SMTP_SRVR -j ACCEPT

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 25 --dport $UNPRIVPORTS -s $SMTP_SRVR -d $EXTERNAL_IP -j ACCEPT

	      if [ $MASQUERADING -gt 0 ]; then
	         iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $SMTP_SRVR --sport $UNPRIVPORTS --dport 25 -j ACCEPT
	         iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $SMTP_SRVR -d $INTERNAL_NETWORK \
		  --sport 25 --dport $UNPRIVPORTS -j ACCEPT
	      fi

	      if [ $VERBOSE -gt 0 ]; then
	  	 echo "firewall: Clients may access remote SMTP server: ${SMTP_SRVR}"
	      fi
	   done
	fi

	#
	# Sending Mail through a local SMTP server (25)
	#

	if [ $SMTP_LOCAL_SERVER -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 25 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 25 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    # Receiving Mail as a Local SMTP server (25)

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 25 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 25 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: SMTP Local server enabled"
	    fi

	fi


	#
	# Sending Mail through a remote Secure SMTP server (465)
	#

	if [ $SSMTP_REMOTE_SERVER -gt 0 ]; then

	   # SSMTP client to an ISP account without a local server
	   for SSMTP_SRVR in ${SSMTP_SERVER}; do
 	
	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 465 -s $EXTERNAL_IP -d $SSMTP_SRVR -j ACCEPT

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 465 --dport $UNPRIVPORTS -s $SSMTP_SRVR -d $EXTERNAL_IP -j ACCEPT

	      if [ $MASQUERADING -gt 0 ]; then
	         iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $SSMTP_SRVR --sport $UNPRIVPORTS --dport 465 -j ACCEPT
	         iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $SSMTP_SRVR -d $INTERNAL_NETWORK \
		  --sport 465 --dport $UNPRIVPORTS -j ACCEPT
	      fi

	      if [ $VERBOSE -gt 0 ]; then
	  	 echo "firewall: Clients may access remote Secure SMTP server: ${SSMTP_SRVR}"
	      fi
	   done
	fi

	#
	# Sending Mail through a local Secure SMTP server (465)
	#

	if [ $SSMTP_LOCAL_SERVER -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 465 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 465 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    # Receiving Mail as a Local Secure SMTP server (465)

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 465 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 465 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Secure SMTP Local server enabled"
	    fi

	fi

	#
	# Sending Mail through a remote TLS server (587)
	#

	if [ $TLS_REMOTE_SERVER -gt 0 ]; then

	   # TLS client to an ISP account without a local server
	   for TLS_SRVR in ${TLS_SERVER}; do
 	
	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 587 -s $EXTERNAL_IP -d $TLS_SRVR -j ACCEPT

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 587 --dport $UNPRIVPORTS -s $TLS_SRVR -d $EXTERNAL_IP -j ACCEPT

	      if [ $MASQUERADING -gt 0 ]; then
	         iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $TLS_SRVR --sport $UNPRIVPORTS --dport 587 -j ACCEPT
	         iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $TLS_SRVR -d $INTERNAL_NETWORK \
		  --sport 587 --dport $UNPRIVPORTS -j ACCEPT
	      fi

	      if [ $VERBOSE -gt 0 ]; then
	  	 echo "firewall: Clients may access remote TLS server: ${TLS_SRVR}"
	      fi
	   done
	fi

	#
	# Sending Mail through a local TLS server (587)
	#

	if [ $TLS_LOCAL_SERVER -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 587 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 587 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    # Receiving Mail as a Local TLS  server (587)

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 587 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 587 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: TLS Local server enabled"
	    fi

	fi



	#
	# POP3 (110) - Retrieving Mail as a POP3 client
	#

	if [ $POP3_CLIENT -gt 0 ]; then
	   for POP_SRVR in ${POP_SERVER}; do
 	   
	       iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 110 -s $EXTERNAL_IP -d $POP_SRVR -j ACCEPT

	       iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 110 --dport $UNPRIVPORTS -s $POP_SRVR -d $EXTERNAL_IP -j ACCEPT

	       if [ $MASQUERADING -gt 0 ]; then
	          iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $POP_SRVR --sport $UNPRIVPORTS --dport 110 -j ACCEPT
	          iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $POP_SRVR -d $INTERNAL_NETWORK \
		   --sport 110 --dport $UNPRIVPORTS -j ACCEPT
	       fi

	       if [ $VERBOSE -gt 0 ]; then
		   echo "firewall: Clients may access remote POP-3 server: ${POP_SRVR}"
	       fi
	   done

	fi



	#
	# POP3 (110) - Hosting a POP3 server for remote clients
	#

	if [ $POP3_SERVER -gt 0 ]; then
	   for MY_POP3_CLIENT in ${MY_POP3_CLIENTS}; do

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 110 -s $MY_POP3_CLIENT -d $EXTERNAL_IP -j ACCEPT

	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 110 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $MY_POP3_CLIENT -j ACCEPT

	       if [ $VERBOSE -gt 0 ]; then
	          echo "firewall: Remote site ${MY_POP3_CLIENT} may access local POP-3 server"
	       fi

	   done
	fi



        #
        # POP3S (995) - Retrieving Mail as a POP3S client
        #

        if [ $POP3S_CLIENT -gt 0 ]; then
           for POP3S_SRVR in ${POP3S_SERVERS}; do

               iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
           --sport $UNPRIVPORTS --dport 995 -s $EXTERNAL_IP -d $POP3S_SRVR -j ACCEPT

               iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
           --sport 995 --dport $UNPRIVPORTS -s $POP3S_SRVR -d $EXTERNAL_IP -j ACCEPT

               if [ $MASQUERADING -gt 0 ]; then
                  iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $POP3S_SRVR --sport $UNPRIVPORTS --dport 995 -j ACCEPT
                  iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $POP3S_SRVR -d $INTERNAL_NETWORK \
                   --sport 995 --dport $UNPRIVPORTS -j ACCEPT
               fi

               if [ $VERBOSE -gt 0 ]; then
                   echo "firewall: Clients may access remote POP-3 secure server: ${POP3S_SRVR}"
               fi
           done

        fi


	#
        # POP3S (995) - Hosting a secure POP3 server for remote clients
        #

        if [ $POP3S_SERVER -gt 0 ]; then
           for MY_POP3S_CLIENT in ${MY_POP3S_CLIENTS}; do

              iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
           --sport $UNPRIVPORTS --dport 995 -s $MY_POP3S_CLIENT -d $EXTERNAL_IP -j ACCEPT

              iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
           --sport 995 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $MY_POP3S_CLIENT -j ACCEPT

               if [ $VERBOSE -gt 0 ]; then
                  echo "firewall: Remote site ${MY_POP3S_CLIENT} may access local secure POP-3 server"
               fi

           done
        fi



	#
	# IMAP (143) - Retrieving Mail as an IMAP client
	#

	if [ $IMAP_CLIENT -gt 0 ]; then
	   for IMAP_SRVR in ${MY_IMAP_SERVER}; do
		
	       iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 143 -s $EXTERNAL_IP -d $IMAP_SRVR -j ACCEPT

	       iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 143 --dport $UNPRIVPORTS -s $IMAP_SRVR -d $EXTERNAL_IP -j ACCEPT

	       if [ $MASQUERADING -gt 0 ]; then
	          iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $IMAP_SRVR --sport $UNPRIVPORTS --dport 143 -j ACCEPT
	          iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $IMAP_SRVR -d $INTERNAL_NETWORK \
		   --sport 143 --dport $UNPRIVPORTS -j ACCEPT
	       fi

	       if [ $VERBOSE -gt 0 ]; then
		  echo "firewall: Clients may access remote IMAP server: ${IMAP_SRVR}"
	       fi
	   done

	fi

	#
	# IMAP (143) - Hosting an IMAP server for remote clients
	#

	if [ $IMAP_SERVER -gt 0 ]; then
	   for MY_IMAP_CLIENT in ${MY_IMAP_CLIENTS}; do

	       iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 143 -s $MY_IMAP_CLIENT -d $EXTERNAL_IP -j ACCEPT

  	       iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 143 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $MY_IMAP_CLIENTS -j ACCEPT

	     if [ $VERBOSE -gt 0 ]; then
	  	echo "firewall: Remote site ${MY_IMAP_CLIENT} may access local IMAP server"
	     fi

	   done
	fi

	#
	# IMAPS (993) - Retrieving Mail as an Secure IMAP client
	#

	if [ $IMAPS_CLIENT -gt 0 ]; then
	   for IMAPS_SRVR in ${MY_IMAPS_SERVER}; do

	       iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 993 -s $EXTERNAL_IP -d $IMAPS_SRVR -j ACCEPT

	       iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 993 --dport $UNPRIVPORTS -s $IMAPS_SRVR -d $EXTERNAL_IP -j ACCEPT

	       if [ $MASQUERADING -gt 0 ]; then
	          iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $IMAPS_SRVR --sport $UNPRIVPORTS --dport 993 -j ACCEPT
	          iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $IMAPS_SRVR -d $INTERNAL_NETWORK \
		   --sport 993 --dport $UNPRIVPORTS -j ACCEPT
	       fi

	       if [ $VERBOSE -gt 0 ]; then
		  echo "firewall: Clients may access remote Secure IMAP server: ${IMAPS_SRVR}"
	       fi
	   done

	fi

	#
	# IMAPS (993) - Hosting a Secure IMAP server for remote clients
	#

	if [ $IMAPS_SERVER -gt 0 ]; then
	   for MY_IMAPS_CLIENT in ${MY_IMAPS_CLIENTS}; do

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 993 -s $MY_IMAPS_CLIENT -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 993 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $MY_IMAPS_CLIENT -j ACCEPT

	       if [ $VERBOSE -gt 0 ]; then
	  	  echo "firewall: Remote site ${MY_IMAPS_CLIENT} may access local Secure IMAP server"
	       fi

	   done
	fi

	#
	# NNTP (119) - Reading and posting news as a Usenet client
	#

	if [ $NNTP_CLIENT -gt 0 ]; then
	   for NEWS_SRVR in ${NEWS_SERVER}; do
	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 119 -s $EXTERNAL_IP -d $NEWS_SRVR -j ACCEPT

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 119 --dport $UNPRIVPORTS -s $NEWS_SRVR -d $EXTERNAL_IP -j ACCEPT

	       if [ $MASQUERADING -gt 0 ]; then
	          iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $NEWS_SRVR --sport $UNPRIVPORTS --dport 119 -j ACCEPT
	          iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $NEWS_SRVR -d $INTERNAL_NETWORK \
		   --sport 119 --dport $UNPRIVPORTS -j ACCEPT
	       fi

	       if [ $VERBOSE -gt 0 ]; then
		  echo "firewall: Clients may access remote NNTP server: ${NEWS_SRVR}"
	       fi
	   done
	fi

	#
	# NNTP (119) - Hosting a Usenet news server for remote clients
	#

	if [ $NNTP_SERVER -gt 0 ]; then
	   for NNTP_CLIENT in ${MY_NNTP_CLIENTS}; do
	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 119 -s $NNTP_CLIENT -d $EXTERNAL_IP -j ACCEPT

	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 119 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $NNTP_CLIENT -j ACCEPT

	      if [ $VERBOSE -gt 0 ]; then
		 echo "firewall: Remote client ${NNTP_CLIENT} may access local NNTP server"
	      fi
	   done
	fi

	#
	# NNTP (119) - Allowing peer news feeds for a local Usenet server
	#

	if [ $NNTP_NEWS_FEED -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 119 -s $EXTERNAL_IP -d $MY_NEWS_FEED -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 119 --dport $UNPRIVPORTS -s $MY_NEWS_FEED -d $EXTERNAL_IP -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: External NNTP News feed access enabled"
	    fi

	fi

	#
        # Secure NNTP (563) - Reading and posting news as a Usenet client over SSL
        # Submitted by Renaud Colinet
	#

        if [ $NNTPS_CLIENT -gt 0 ]; then
	   for SNEWS_SRVR in ${SNEWS_SERVER}; do 
              iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
           --sport $UNPRIVPORTS --dport 563 -s $EXTERNAL_IP -d $SNEWS_SRVR -j ACCEPT

              iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
           --sport 563 --dport $UNPRIVPORTS -s $SNEWS_SRVR -d $EXTERNAL_IP -j ACCEPT

              if [ $MASQUERADING -gt 0 ]; then
                 iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK -d $SNEWS_SRVR --sport $UNPRIVPORTS --dport 563 -j ACCEPT
                 iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -s $SNEWS_SRVR -d $INTERNAL_NETWORK \
                  --sport 563 --dport $UNPRIVPORTS -j ACCEPT
              fi

              if [ $VERBOSE -gt 0 ]; then
                 echo "firewall: Clients may access remote secure NNTP server: ${SNEWS_SRVR}"
              fi
	   done
        fi

	#
	# TELNET (23) - Allowing outgoing client access to remote sites
	#

	if [ $TELNET_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 23 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 23 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 23 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 23 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote TELNET servers"
	    fi

	fi

	#
	# TELNET (23) - Allowing incoming access to your local server
	# Note:  Not recommended! Suggest SSH instead!
	#

	if [ $TELNET_SERVER -gt 0 ]; then
	   for MY_TELNET_CLIENT in ${MY_TELNET_CLIENTS}; do

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 23 -s $MY_TELNET_CLIENTS -d $EXTERNAL_IP -j ACCEPT

	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 23 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $MY_TELNET_CLIENTS -j ACCEPT

	       if [ $VERBOSE -gt 0 ]; then
		  echo "firewall: Remote site ${MY_TELNET_CLIENT} may access local TELNET server"
	       fi
	   done

	fi

	#
	# SSH Client (22) - Allowing client access to remote SSH servers
	#

	if [ $SSH_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 22 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 22 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $SSH_HI_PORTS --dport 22 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 22 --dport $SSH_HI_PORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 22 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 22 --dport $UNPRIVPORTS -j ACCEPT
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $SSH_HI_PORTS --dport 22 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 22 --dport $SSH_HI_PORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote SSH servers"
	    fi

	fi

	#
	# SSH (see config) - Allowing remote client access to your local SSH server
	#

	if [ $SSH_SERVER -gt 0 ]; then
	   for MY_SSH_CLIENT in ${MY_SSH_CLIENTS}; do

	       iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport $SSH_PORT -s $MY_SSH_CLIENT -d $EXTERNAL_IP -j ACCEPT

	       iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport $SSH_PORT --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $MY_SSH_CLIENT -j ACCEPT

	       iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $SSH_HI_PORTS --dport $SSH_PORT -s $MY_SSH_CLIENT -d $EXTERNAL_IP -j ACCEPT

	       iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	    --sport $SSH_PORT --dport $SSH_HI_PORTS -s $EXTERNAL_IP -d $MY_SSH_CLIENT -j ACCEPT

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Remote site ${MY_SSH_CLIENT} may access local SSH server"
	    fi
	done

	fi


	#
	# FTP (20, 21) - Allowing outgoing client access to remote FTP servers
	# See note for FTP server, below.  We will simply load up the modules below:

	if [ $FTP_CLIENT -gt 0 ]; then
	  /sbin/modprobe ip_conntrack
	  /sbin/modprobe ip_conntrack_ftp
	  # /sbin/modprobe ip_nat_ftp

            # Outgoing request

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
        --sport 21 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state NEW,ESTABLISHED \
        --sport $UNPRIVPORTS --dport 21 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

            # Normal Port mode FTP data channels

#           iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state NEW \
#       --sport 20 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
        --sport $UNPRIVPORTS --dport 20 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

            # Passive mode FTP data channels

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
        --sport $UNPRIVPORTS --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state NEW,ESTABLISHED \
        --sport $UNPRIVPORTS --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 20:21 -j ACCEPT
	       iptables -A FORWARD -p TCP -d $INTERNAL_NETWORK --sport 20:21 --dport $UNPRIVPORTS -j ACCEPT
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport $UNPRIVPORTS -j ACCEPT
	       iptables -A FORWARD -p TCP -d $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote FTP servers"
	    fi

	fi

	#
	# FTP (20, 21) - Allowing incoming access to your local FTP server
	#

      	if [ $FTP_SERVER -gt 0 ]; then

	  /sbin/modprobe ip_conntrack
	  /sbin/modprobe ip_conntrack_ftp
	  # /sbin/modprobe ip_nat_ftp   # load if FTP server behind NATted firewall

          for MY_FTP_CLIENT in ${MY_FTP_CLIENTS}; do	
	     iptables -A INPUT -p tcp -i $EXTERNAL_INTERFACE -s $MY_FTP_CLIENT --sport 1024:65535 -d $EXTERNAL_IP --dport 21 -m state --state NEW,ESTABLISHED -j ACCEPT
	     iptables -A OUTPUT -p tcp -o $EXTERNAL_INTERFACE -s $EXTERNAL_IP --sport 21 -d $MY_FTP_CLIENT --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
	     iptables -A INPUT -p tcp -i $EXTERNAL_INTERFACE -s $MY_FTP_CLIENT --sport 1024:65535 -d $EXTERNAL_IP --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT
	     iptables -A OUTPUT -p tcp -o $EXTERNAL_INTERFACE -s $EXTERNAL_IP --sport 1024:65535 -d $MY_FTP_CLIENT --dport 1024:65535 -m state --state ESTABLISHED -j ACCEPT
	     iptables -A OUTPUT -p tcp -o $EXTERNAL_INTERFACE -s $EXTERNAL_IP --sport 20 -d $MY_FTP_CLIENT --dport 1024:65535 -m state --state ESTABLISHED,RELATED -j ACCEPT
	     iptables -A INPUT -p tcp -i $EXTERNAL_INTERFACE -s $MY_FTP_CLIENT --sport 1024:65535 -d $EXTERNAL_IP --dport 20 -m state --state ESTABLISHED -j ACCEPT
	  done
                
	  if [ $VERBOSE -gt 0 ]; then
             echo "firewall: Remote clients may access local FTP server"
          fi
	fi

	#
	# HTTP (80) - Accessing remote web sites as a client
	#

	if [ $HTTP_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 80 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 80 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 80 -j ACCEPT
	       iptables -A FORWARD -p TCP -d $INTERNAL_NETWORK --sport 80 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote HTTP servers"
	    fi

	fi

	#
	# HTTP (80) - Allowing remote access to a local web server
	#

	if [ $HTTP_SERVER -gt 0 ]; then
	   for HTTP_CLIENT in ${MY_HTTP_CLIENTS}; do
	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 80 -s $HTTP_CLIENT -d $EXTERNAL_IP -j ACCEPT

	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 80 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $HTTP_CLIENT -j ACCEPT

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 8080 -s $HTTP_CLIENT -d $EXTERNAL_IP -j ACCEPT

	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 8080 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $HTTP_CLIENT -j ACCEPT

	      if [ $VERBOSE -gt 0 ]; then
		 echo "firewall: Remote client ${HTTP_CLIENT} may access local HTTP server"
	      fi
	   done
	fi


	#
	# HTTPS (443) - Accessing remote web sites over SSL as a client
	#

	if [ $HTTPS_CLIENT -gt 0 ]; then	
	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 443 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 443 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 443 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 443 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote HTTPS servers"
	    fi

	fi

	#
	# HTTPS (443) - Allowing remote access to a local SSL web server
	#

	if [ $HTTPS_SERVER -gt 0 ]; then
	   for HTTPS_CLIENT in ${MY_HTTPS_CLIENTS}; do
	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 443 -s $HTTPS_CLIENT -d $EXTERNAL_IP -j ACCEPT

	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 443 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $HTTPS_CLIENT -j ACCEPT

	      if [ $VERBOSE -gt 0 ]; then
		 echo "firewall: Remote client ${HTTPS_CLIENT} may access local HTTPS server"
	      fi
	   done
	fi

	#
	# HTTP Proxy Client (8008/8080)
	#

	if [ $HTTP_PROXY -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport $WEB_PROXY_PORT -s $EXTERNAL_IP -d $WEB_PROXY_SERVER -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport $WEB_PROXY_PORT --dport $UNPRIVPORTS -s $WEB_PROXY_SERVER -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport $WEB_PROXY_PORT -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport $WEB_PROXY_PORT --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote sites via HTTP Proxy Server"
	    fi

	fi


	#
	# FINGER (79) - Accessing remote finger servers as a client
	#

	if [ $FINGER_CLIENT -gt 0 ]; then
	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 79 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 79 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 79 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 79 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote FINGER servers"
	    fi

	fi

	#
	# FINGER (79) - Allowing remote client access to a local finger server (dangerous!)
	#

	if [ $FINGER_SERVER -gt 0 ]; then
	   for FINGER_CLIENT in ${MY_FINGER_CLIENTS}; do

	      iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	   --sport $UNPRIVPORTS --dport 79 -s $FINGER_CLIENT -d $EXTERNAL_IP -j ACCEPT

	      iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	   --sport 79 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $FINGER_CLIENT -j ACCEPT

	      if [ $VERBOSE -gt 0 ]; then
		 echo "firewall: Remote client ${FINGER_CLIENT} may access local FINGER server"
	      fi
	   done
	fi

	#
	# WHOIS (43) - Accessing a remote WHOIS server as a client
	#

	if [ $WHOIS_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 43 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 43 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 43 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 43 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote WHOIS servers"
	    fi

	fi

	#
	# GOPHER (70) - Accessing a remote GOPHER server as a client
	#

	if [ $GOPHER_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 70 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 70 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 70 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 70 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote GOPHER servers"
	    fi

	fi

	#
	# WAIS (210) - Accessing a remote WAIS server as a client
	#

	if [ $WAIS_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	--sport $UNPRIVPORTS --dport 210 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP -m state --state ESTABLISHED,RELATED \
	--sport 210 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 210 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 210 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Clients may access remote WAIS servers"
	    fi

	fi

	#
        # Real Video (554) - Real Video Client
        #

        if [ $RV_CLIENT -gt 0 ]; then
            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
               --sport $UNPRIVPORTS --dport 554 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
               --sport 554 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 554 -j ACCEPT
	       iptables -A FORWARD -m state --state ESTABLISHED,RELATED -p TCP -d $INTERNAL_NETWORK \
		--sport 554 --dport $UNPRIVPORTS -j ACCEPT
	    fi

            if [ $VERBOSE -gt 0 ]; then
                echo "firewall: Real Video client enabled"
            fi
        fi

        #
        # PPTP (1723) - Accessing PPTP servers as a client
        #

        if [ $PPTP_CLIENT -gt 0 ]; then

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
                --sport $UNPRIVPORTS --dport 1723 \
                -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP  \
                --sport 1723 --dport $UNPRIVPORTS \
                -s $ANYWHERE -d $EXTERNAL_IP \
                -m state --state ESTABLISHED,RELATED -j ACCEPT

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p 47 -m state --state NEW -j DROP
            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p 47 -m state --state NEW -j DROP

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p 47 -j ACCEPT
            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p 47 -j ACCEPT

            if [ $MASQUERADING -gt 0 ]; then

               iptables -A INPUT -i $INTERNAL_INTERFACE -p 47 -m state --state NEW -j DROP
               iptables -A OUTPUT -o $INTERNAL_INTERFACE -p 47 -m state --state NEW -j DROP

               iptables -A INPUT -i $INTERNAL_INTERFACE -p 47 -j ACCEPT
               iptables -A OUTPUT -o $INTERNAL_INTERFACE -p 47 -j ACCEPT

               iptables -A FORWARD -p TCP -s $INTERNAL_NETWORK \
                  --sport $UNPRIVPORTS --dport 1723 -j ACCEPT

               iptables -A FORWARD -p TCP -d $INTERNAL_NETWORK \
                  -m state --state ESTABLISHED,RELATED \
                  --sport 1723 --dport $UNPRIVPORTS -j ACCEPT

               iptables -A FORWARD -p 47 -s $INTERNAL_NETWORK -j ACCEPT
               iptables -A FORWARD -p 47 -d $INTERNAL_NETWORK -j ACCEPT

            fi

            if [ $VERBOSE -gt 0 ]; then
                echo "firewall: Clients may access remote PPTP servers"
            fi

        fi

	#
	# UDP - Accept only on selected ports
	#

	#
	# TRACEROUTE
	#
	# Traceroute usually uses -s 32769:65535 -d 33434:33523
	#

	if [ $OUTBOUND_TRACEROUTE -gt 0 ]; then

	    # Enable outgoing TRACEROUTE requests

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	--sport $TRACEROUTE_SRC_PORTS --dport $TRACEROUTE_DEST_PORTS \
	-s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p UDP -s $INTERNAL_NETWORK --sport $TRACEROUTE_SRC_PORTS \
		--dport $TRACEROUTE_DEST_PORTS -j ACCEPT
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK --sport $TRACEROUTE_DEST_PORTS \
		--dport $TRACEROUTE_SRC_PORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Outbound TRACEROUTE enabled"
	    fi

	fi

	if [ $INBOUND_TRACEROUTE -gt 0 ]; then

	    # Enable incoming TRACEROUTE query

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	--sport $TRACEROUTE_SRC_PORTS --dport $TRACEROUTE_DEST_PORTS \
	-s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK --sport $TRACEROUTE_SRC_PORTS \
		--dport $TRACEROUTE_DEST_PORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Inbound TRACEROUTE enabled"
	    fi

	fi


        #
        # DHCP Server
	#
        # This assumes that you're running a DHCP server on your firewall to
        # supply IP addresses to your internal network using dhcpd.  See any
        # of several DHCP HowTo sites for the actual server setup.
        #

        if [ $DHCP_SERVER -gt 0 ]; then

            iptables -A INPUT -i $INTERNAL_INTERFACE -p udp -s $BROADCAST_SRC \
        -d $BROADCAST_DEST --sport 67:68 --dport 67:68 -j ACCEPT
            iptables -A OUTPUT -o $INTERNAL_INTERFACE -p udp -s $INTERNAL_IP \
        --sport 67:68 --dport 67:68 -j ACCEPT
            iptables -A FORWARD -p udp -s $INTERNAL_NETWORK --sport 67:68 --dport 67:68 -j ACCEPT
	    iptables -A FORWARD -p udp -d $INTERNAL_NETWORK --sport 67:68 --dport 67:68 -j ACCEPT

           if [ $VERBOSE -gt 0 ]; then
                echo "firewall: DHCP Server enabled"
           fi

        fi


        #
        # NTP (123) - Accessing remote Network Time Servers
        #

        if [ $NTP_CLIENT -gt 0 ]; then

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
        --sport $UNPRIVPORTS --dport 123 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
        --sport 123 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

            iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
        --sport 123 --dport 123 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

            iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
        --sport 123 --dport 123 -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p UDP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 123 -j ACCEPT
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK --sport 123 --dport $UNPRIVPORTS -j ACCEPT
	       iptables -A FORWARD -p UDP -s $INTERNAL_NETWORK --sport 123 --dport 123 -j ACCEPT
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK --sport 123 --dport 123 -j ACCEPT
	    fi

            if [ $VERBOSE -gt 0 ]; then
                echo "firewall: NTP Client enabled"
            fi

        fi


	#
	# ICQ (4000) - The Miribilis ICQ Client
	#

	if [ $ICQ_CLIENT -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	--sport $UNPRIVPORTS --dport 4000 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	--sport 4000 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p UDP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 4000 -j ACCEPT
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK --sport 4000 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
	        echo "firewall: ICQ Client enabled"
	    fi

	fi

	#
	# GAMES
	#

	#
	# Game Consoles - XBox 360, PS2, Wii, etc. - these talk to outside servers and need essentially
	#		  unfettered access.  This essentially allows everything out from their internal
	#		  IP addresses, and allows ESTABLISHED, RELATED packets in.  Multicast may also 
	#		  be necessary.	 
        #		  You may also need to consider using the linux-igd package.
	#		  You may also need to open specific ports via:
	#		  /etc/firewall/firewall.nat:
	#		  XBox Live: UDP 88, 3074 and TCP 3074

	if [ $CONSOLE -gt 0 ]; then
	   strlen=${#CONSOLE_IPs}
           if [ "$strlen" -gt 0 ]; then
	      for CONSOLE_IP in ${CONSOLE_IPs}; do
		 # Outbound
		 iptables -A FORWARD -p TCP -s $CONSOLE_IP -m state --state NEW,ESTABLISHED -j ACCEPT
		 iptables -A FORWARD -p UDP -s $CONSOLE_IP -m state --state NEW,ESTABLISHED -j ACCEPT
		 # Inbound
		 iptables -A FORWARD -p TCP -d $CONSOLE_IP -m state --state ESTABLISHED,RELATED -j ACCEPT
		 iptables -A FORWARD -p UDP -d $CONSOLE_IP -m state --state ESTABLISHED,RELATED -j ACCEPT
	      
		 echo "firewall: Game console at "$CONSOLE_IP" given full access."
	      done
	   fi
	fi


	#
	# Half-Life/CounterStrike
	#

	if [ $HALF_LIFE -gt 0 ]; then

	    iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	--sport 27000:27050 --dport $UNPRIVPORTS -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT

	    iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	-m state --state RELATED,ESTABLISHED,NEW --dport 27000:27050 -s $ANYWHERE \
	-d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p UDP -s $INTERNAL_NETWORK --sport 27000:27050 --dport $UNPRIVPORTS -j ACCEPT
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK -m state --state RELATED,ESTABLISHED,NEW --dport 27000:27050 -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
	        echo "firewall: Half-Life/CounterStrike game ports enabled"
	    fi

	fi
	
	#
	# Return to Castle Wolfenstein
	#

	if [ $WOLF_CLIENT -gt 0 ]; then

	    iptables  -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	--sport $UNPRIVPORTS --dport 27950:27965 -s $EXTERNAL_IP -d $ANYWHERE -j ACCEPT
	    iptables  -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	--sport 27950:27965 --dport $UNPRIVPORTS -s $ANYWHERE -d $EXTERNAL_IP -j ACCEPT

	    if [ $MASQUERADING -gt 0 ]; then
	       iptables -A FORWARD -p UDP -s $INTERNAL_NETWORK --sport $UNPRIVPORTS --dport 27950:27965 -j ACCEPT
	       iptables -A FORWARD -p UDP -d $INTERNAL_NETWORK --sport 27950:27965 --dport $UNPRIVPORTS -j ACCEPT
	    fi

	    if [ $VERBOSE -gt 0 ]; then
	        echo "firewall: Castle Wolfenstein game ports enabled"
	    fi
	fi


	# -------------------------------------------------------------

	#
	# Spoofing and Bad Addresses
	#

	# Refuse spoofed packets.
	# Ignore blatantly illegal source addresses.
	# Protect yourself from sending to bad addresses.

	# Refuse spoofed packets pretending to be from
	# the external interface's IP address.

	iptables -A INPUT -i $EXTERNAL_INTERFACE -s $EXTERNAL_IP -j LnD

	# Get first two octets of external IP address

        OCT1=$( ifconfig $EXTERNAL_INTERFACE | sed -n '2s/^.*inet addr:\([0-9][0-9]*\).*/\1/p' )
        OCT2=$( ifconfig $EXTERNAL_INTERFACE | sed -n '2s/^.*inet addr:\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' )
        OCT3=$( echo $OCT2 | sed 's/^[0-9].\.//g' )


        if [ $OCT1 != "10" ]; then

           # Refuse packets claiming to be to or from a Class-A private network.

           iptables -A INPUT -i $EXTERNAL_INTERFACE -s $CLASS_A -j LnD
           iptables -A INPUT -i $EXTERNAL_INTERFACE -d $CLASS_A -j LnD
           iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $CLASS_A -j LnD
           iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $CLASS_A -j LnD

        fi

        if [ $OCT1 != "172" ]; then  

           # Refuse packets claiming to be to or from a Class-B private network.

           iptables -A INPUT -i $EXTERNAL_INTERFACE -s $CLASS_B -j LnD
           iptables -A INPUT -i $EXTERNAL_INTERFACE -d $CLASS_B -j LnD
           iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $CLASS_B -j LnD
           iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $CLASS_B -j LnD

	fi

	if [ $OCT1 = "172" ]; then

	   if [ $OCT3 -lt "15" ] || [ $OCT3 -gt "31" ]; then 	

              # Refuse packets claiming to be to or from a Class-B private network.

              iptables -A INPUT -i $EXTERNAL_INTERFACE -s $CLASS_B -j LnD
              iptables -A INPUT -i $EXTERNAL_INTERFACE -d $CLASS_B -j LnD
              iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $CLASS_B -j LnD
              iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $CLASS_B -j LnD
	   fi

	fi

        if [ $OCT2 != "192.168" ]; then

           # Refuse packets claiming to be to or from a Class-C private network.

           iptables -A INPUT -i $EXTERNAL_INTERFACE -s $CLASS_C -j LnD
           iptables -A INPUT -i $EXTERNAL_INTERFACE -d $CLASS_C -j LnD
           iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $CLASS_C -j LnD
           iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $CLASS_C -j LnD

        fi

	# Refuse packets claiming to be from the loopback.

	iptables -A INPUT -i $EXTERNAL_INTERFACE -s $LOOPBACK_NETWORK -j LnD
	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $LOOPBACK_NETWORK -j LnD

	# Refuse malformed broadcast packets.

	iptables -A INPUT -i $EXTERNAL_INTERFACE -s $BROADCAST_DEST -j LnD
	iptables -A INPUT -i $EXTERNAL_INTERFACE -d $BROADCAST_SRC  -j LnD
	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $BROADCAST_DEST -j LnD
	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $BROADCAST_SRC  -j LnD

	# Refuse Class-D Multicast addresses.
	# Multicast is only illegal as a source address.
	# Multicast uses UDP.
	# Game consoles accessing outside servers likely require multicast to be enabled. 

	if [ $CONSOLE -eq 0 ]; then
	   iptables -A INPUT -i $EXTERNAL_INTERFACE -s $CLASS_D_MULTICAST -j LnD
	   iptables -A OUTPUT -o $EXTERNAL_INTERFACE -s $CLASS_D_MULTICAST -j LnR
	fi

	# Refuse Class-E reserved IP addresses.

	iptables -A INPUT -i $EXTERNAL_INTERFACE -s $CLASS_E_RESERVED_NET -j LnD
	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -d $CLASS_E_RESERVED_NET -j LnR


	# -------------------------------------------------------------

	#
	# DROP (on input), REJECT (output) and LOG anything else on the external (red) interface
	#

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p TCP \
	    -s $ANYWHERE -j LnD

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p TCP \
	    -s $ANYWHERE -j LnR

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p UDP \
	    -s $ANYWHERE -j LnD

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p UDP \
	    -s $ANYWHERE -j LnR

	iptables -A INPUT -i $EXTERNAL_INTERFACE -p ICMP \
	    -s $ANYWHERE -j LnD

	iptables -A OUTPUT -o $EXTERNAL_INTERFACE -p ICMP \
	    -s $ANYWHERE -j LnR


	#
	# Masquerade internal traffic
	#

	if [ $MASQUERADING -gt 0 ]; then


	    # All internal traffic is masqueraded externally

	    iptables -t nat -A POSTROUTING -s $INTERNAL_NETWORK -o $EXTERNAL_INTERFACE -j SNAT \
	    --to $EXTERNAL_IP

            # Note: some may find this works better on machines with non-static 
	    # external IP addresses:
            # iptables -t nat -A POSTROUTING -o ethX -j MASQUERADE
 

	    # Enable IP Forwarding
	
	    echo 1 >/proc/sys/net/ipv4/ip_forward

	    #
	    # Unlimited traffic within the local network
	    #

	    # All internal machines have access to the firewall machine

	    iptables -A INPUT -i $INTERNAL_INTERFACE -s $INTERNAL_NETWORK -j ACCEPT

	    iptables -A OUTPUT -o $INTERNAL_INTERFACE -d $INTERNAL_NETWORK -j ACCEPT

            if [ $VERBOSE -gt 0 ]; then
		echo "firewall: Masquerading internal network"
	    fi
	fi


	# -------------------------------------------------------------

	# Zero counts
	iptables -Z

	# -------------------------------------------------------------

	echo "done"
	touch /var/lock/subsys/firewall
	echo
	;;

  status)
  	if [ -f /var/lock/subsys/firewall ]; then
	    echo "Firewall started and configured"
	else
	    echo "Firewall stopped"
	fi
	exit 0
	;;

  restart|reload)
	$0 stop
	$0 start
	;;

  stop)
  	echo "Shutting down Firewall services"

	# Turn off IP Forwarding
	echo 0 >/proc/sys/net/ipv4/ip_forward

	# Turn off dynamic IP hacking
      	echo 0 > /proc/sys/net/ipv4/ip_dynaddr

	# Flush the rule chains
	iptables -F

	# Delete custom chains
	iptables -X

	# Zero counts
	iptables -Z

	# Set the default policy to DROP
	iptables -P INPUT DROP
	iptables -P OUTPUT DROP
	iptables -P FORWARD DROP

	# Allow unlimited traffic on the loopback interface
	iptables -A INPUT -i $LOOPBACK_INTERFACE -j ACCEPT
	iptables -A OUTPUT -o $LOOPBACK_INTERFACE -j ACCEPT

	# Open the configuration file
	if [ -f /etc/firewall/firewall.conf.iptables ]; then
	    . /etc/firewall/firewall.conf.iptables

            if [ $MASQUERADING -gt 0 ]; then
                # Allow unlimited local traffic on the internal interface
                iptables -A INPUT -i $INTERNAL_INTERFACE -j ACCEPT
                iptables -A OUTPUT -o $INTERNAL_INTERFACE -j ACCEPT
	    fi
	else
	    echo "firewall: No configuration file found at /etc/firewall/firewall.conf.iptables"
	    exit 1
	fi

	rm -f /var/lock/subsys/firewall
	echo
	;;
  *)
	echo "Usage: /etc/rc.d/init.d/firewall.iptables {start|stop|status|restart|reload}"
	exit 1
esac

exit 0
