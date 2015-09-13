#!/bin/bash

zone_path="/var/named/master/auto"
url="http://zenoss.sib.transtk.ru:8000/ipam/domains/?zone="
list_url="http://zenoss.sib.transtk.ru:8000/ipam/domain-list/"

for zone in $(curl -s $list_url); do
	printf "Download $zone zone file . . . "
	rm -f /tmp/$zone
	/bin/curl -s "$url$zone" > /tmp/$zone
	printf "OK\n"
	printf "Checking zone by named-checkzone . . . "
        if /sbin/named-checkzone -q $zone /tmp/$zone ; then
		printf "OK\n"
		mv /tmp/$zone $zone_path
		echo "Send zone reload command . . . $(/sbin/rndc reload $zone)"
	else
		printf "FAILED!\n"
		rm -f /tmp/$zone
	fi
done
