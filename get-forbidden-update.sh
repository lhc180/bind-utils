#!/bin/bash

url="http://62.33.207.197/dns/list.txt"
domain="^((?!-)[A-Za-z0-9-]{1,63}(?<!-)\\.)+[A-Za-z]{2,6}$"
hash_file="/tmp/zone-update.sha"
tmp_config="/tmp/named.blocked.conf.tmp"
config="/etc/named.blocked.conf"
bind_config="/etc/named.conf"
zone_path="master/blocked.db"

touch $hash_file

printf "\n`date`\n\n"

printf "Forbidden zone list update:\n"
printf "  - trying to download domain list $url ... "
list=`curl -s -S $url`
printf "OK\n"

if [[ $? -eq 0 ]]
then
    printf "  - looking for syntax error ... "
    syntax_error=0
    line_number=0
    while read line
    do
        (( line_number += 1 ))
        if [[ "$line" != "" ]]
        then
            invalid_line=0
            [[ $line =~ ^[a-zA-Z0-9]+([-.]*[a-zA-Z0-9]+)*.[a-zA-Z0-9]+$ ]] && invalid_line=0 || invalid_line=1
            if [[ $invalid_line -eq 1 ]]
            then
                printf "\n      invalid line [$line_number]: $line"
                syntax_error=1
            fi
        fi
    done <<< "$list"
    if [[ $syntax_error -eq 1 ]]
    then
        printf "\nThere are syntax error in the domain list. Abort zones update operation.\n\n"
        exit 1
    else
        printf "OK\n"
    fi
    printf "  - reading current list's hash ... "
    current=`cat $hash_file`
    printf "$current\n"
    printf "  - calculating new list's hash ... "
    hash=`sha256sum <<< $list | grep -o -E [a-z0-9]+`
    printf "$hash\n"
    if [[ "$hash" == "$current" ]]
    then
        printf "There is no any changes domain list contains.\n\n"
        exit 0
    else
        printf "  - making zones configuration ... "
        printf "" > $tmp_config
        while read line
        do
            if [[ "$line" != "" ]]
            then
                printf "zone \"$line\" in { type master; allow-update { none; }; file \"$zone_path\"; };\n" >> $tmp_config
            fi
        done <<< "$list"
        mv -f $tmp_config $config
        chown root:named $config
        printf "OK\n"
        printf "  - checking BIND configuration ..."
        out=`/sbin/named-checkconf -z $bind_config`
        if [[ $? -ne 0 ]]
        then
            printf "FAIL\nThere are errors in the BIND configuration file:\n$out"
            printf "\nAbort zone update operation.\n\n"
            exit 1
        else
            printf "OK\n"
            printf "  - reload BIND configuration ... "
            out=`/sbin/rndc reload`
            printf "$out\n"
            if [[ $? -eq 0 ]]
            then
                printf "Forbidden zones update complete.\n\n"
                printf "$hash" > $hash_file
                exit 0
            else
                print "BIND configuration reload failed.\n\n"
                exit 1
            fi
        fi
    fi
else
    print "FAIL\nFile downloading error. Abort zones update operation\n\n"
    exit 1

fi
