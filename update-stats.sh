#!/bin/bash

if systemctl status named >> /dev/null ; then
    rm -Rf /tmp/named-stats
    rm -f /var/named/data/named_stats.txt
    /sbin/rndc stats
    /bin/python /root/bind-stats-parser/authparser.py -f /var/named/data/named_stats.txt
fi
