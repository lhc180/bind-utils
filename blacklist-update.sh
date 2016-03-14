#/bin/bash

BIND_CONF="/etc/named.conf"
BLACKLIST_CONF="/etc/named.blacklist.conf"
INFO_ZONE="/var/named/master/blacklist.update"
STORED_HASH="/tmp/blacklist.md5"
ZONE_FILE="master/blocked.db"

BLACKLIST_URL="http://62.33.207.197/dns/list.txt"
HASH_URL="http://62.33.207.197/dns/hash.txt"

TMP_BLACKLIST_CONF="/tmp/named.blacklist.conf"
BLACKLIST_FILE="/tmp/blacklist.txt"

FACILITY="local6"

function update_info_zone(){
    info_message="$(date "+%Y-%m-%d %H:%M") $1 Last update hash: $(cat $STORED_HASH)."
    echo "\$TTL 60" > $INFO_ZONE
    echo "@    IN SOA cache-ns3.sibttk.net. root.sibttk.net. $(date +%s) 86400 600 86400 600" >> $INFO_ZONE
    echo "@    IN NS  cache-ns3.sibttk.net." >> $INFO_ZONE
    echo "@    IN NS  cache-ns4.sibttk.net." >> $INFO_ZONE
    echo "info IN TXT \"$info_message\"" >> $INFO_ZONE
    echo "" >> $INFO_ZONE
    info "Update info zone."
    /sbin/rndc reload blacklist.update > /dev/null
}

function log() {
    if [[ $debug_mode == true ]]; then
        echo "$1: $2"
    else
        logger -p $FACILITY.$1 Blacklist update $1: $2
    fi
}

function error() {
    log error "$1"
    update_info_zone "Error: $1"
    exit 1
}

function info() {
    log info "$1"
}

if [[ "$1" == "--debug" ]]; then
    debug_mode=true
else
    debug_mode=false
fi

touch $BLACKLIST_FILE
touch $STORED_HASH

# Download blacklist from the server.
info "Download blacklist from $BLACKLIST_URL."
curl --connect-timeout 5 -s -S $BLACKLIST_URL > $BLACKLIST_FILE
if [[ $? -ne 0 ]]; then
    error "File $BLACKLIST_URL download failed."
fi

# Download blacklist hash from the server.
info "Download control MD5 from $HASH_URL."
server_hash=$(curl --connect-timeout 5 -s -S $HASH_URL)
if [[ $? -ne 0 ]]; then
    error "File $HASH_URL download failed."
fi

# Check if the server stored MD5 doesn't match MD55 of the file was downloaded.
server_hash=$(tr '[:upper:]' '[:lower:]' <<< $server_hash)
list_hash=$(md5sum $BLACKLIST_FILE | grep -E -o "^[a-z0-9]+")

if [[ "$server_hash" != "$list_hash" ]]; then
    error "The new blacklist's MD5-hash $list_hash doesn't match the server MD5-hash $server_hash."
fi

# Check new blacklist's MD5 for equality to locally stored.
if [[ "$list_hash" == "$(cat $STORED_HASH)" ]]; then
    message="The new blacklist's MD5-hash is equal to the locally stored one."
    info "$message"
    update_info_zone "$message"
    exit 0
else
    info "The new blacklist's MD5-hash differs from the locally stored one."
fi

# Check blacklist for domain syntax errors.
info "Check blacklist for domain name syntax errors."
while read line; do
    (( line_number += 1 ))
    if [[ "$line" != "" ]]; then
        invalid_line=0
        [[ $line =~ ^[a-zA-Z0-9]+([-.]*[a-zA-Z0-9]+)*.[a-zA-Z0-9]+$ ]] && invalid_line=0 || invalid_line=1
        if [[ $invalid_line -eq 1 ]]; then
            debug "Invalid blacklist line: $line"
            error "Domain syntax error in line $line_number."
        fi
    fi
done <$BLACKLIST_FILE

# Crate temporally blacklist configuration.
info "Crate blacklist configuration file $BLACKLIST_CONF."
echo "" > $TMP_BLACKLIST_CONF
while read line; do
    echo "zone \"$line\" in { type master; allow-update { none; }; file \"$ZONE_FILE\"; };" >> $TMP_BLACKLIST_CONF
done <$BLACKLIST_FILE
echo "" >> $TMP_BLACKLIST_CONF

# Try to apply the black list and check with named-checkconf.
mv $BLACKLIST_CONF $BLACKLIST_CONF.back
mv $TMP_BLACKLIST_CONF $BLACKLIST_CONF
info "Check new BIND configuration for error."
output=$(/sbin/named-checkconf -z $BIND_CONF)
if [[ $? -ne 0 ]]; then
    mv $BLACKLIST_CONF.back $BLACKLIST_CONF
    error "Bind configuration error."
fi

# Reload BIND configuration.
info "Reload BIND configuration"
output=`/sbin/rndc reload`
if [[ $? -ne 0 ]]; then
    error "Bind configuration reload error."
fi

# Update informational zone.
info "Update stored MD5-hash to $list_hash"
printf $list_hash > $STORED_HASH
update_info_zone "Black list successfully updated."
