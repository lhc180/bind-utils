#!/bin/bash
if systemctl status named >> /dev/null ; then
    address="mail@k-vinogradov.ru"
    result=`/root/zone-update/get-zones.sh`
    if [[ $? -ne 0 ]]; then
        echo "$result" | mutt -s "Cache-NS3 Forbidden Zones Update" $address
    fi
fi
