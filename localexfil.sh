#!bin/bash
# Title:         Local Exfil
# Author:        Simon Camathias
# Version:       0.1
#
# MIT-LICENCED

#setup switches - change these to your prefered settings
NMAP_OPT="--top-ports 20 -O" #change to your prefered settings, do not use -oN
EXT_IP_PROV="https://ipv4.seeip.org" #for checking outbound connections
LOOT_DIR="/root/loot/" #an additional folder with given name will be generated inside this folder
LOOT_FILENAME_PREFIX="" #leave empty for no prefix
LOOT_NAME="" #if left empty, a random name will be generated

#function: send stdin string to lootlog and via serial for debugging purposes
function sendlog() {
    local string=$1
    echo "[DEBUG] $string" >> $LOOT_DEBUG_PATH
    SERIAL_WRITE [*] $string
}

#start the script
LED SETUP

#if no name was given, generate a 8digit hex random number
if [ -z "$LOOT_NAME" ]; then
    LOOT_NAME=$(head /dev/urandom | tr -dc "abcdef0123456789" | head -c8) #get the head of urandom as source, filter that head for HEX-chars and filter for 8 chars
fi

#set the filename
LOOT_FILENAME="${LOOT_FILENAME_PREFIX}_${LOOT_NAME}" 

#set the paths to the files
LOOT_BASIC_PATH="${LOOT_FILENAME}_basicinfo.txt"
LOOT_NMAP_PATH="${LOOT_FILENAME}_nmap.txt"
LOOT_DEBUG_PATH="${LOOT_FILENAME}_debug.log"

#setup loot dir, input headers into files
LOOT_DIR_NEW="${LOOT_DIR}/${LOOT_NAME}"
mkdir -p $LOOT_DIR_NEW # -p is used to make all folders at once
echo "This Data was exfiltrated by Local Exfil for SharkPlug made by bl44ck (MIT-LICENCE)" > $LOOT_BASIC_PATH
echo "See aditional files: ./nmap.txt" >> $LOOT_BASIC_PATH
echo "[INFO] Start Output" >> $LOOT_DEBUG_PATH

#get ip via dhcp
sendlog "configuring DHCP"
NETMODE DHCP_CLIENT
sendlog "waiting to get local IP"
while [ -z "$SUBNET" ]; do
    sleep 1 && SUBNET=$(ip addr | grep -i eth0 | grep -i inet | grep -E -o "([0-9]{1,3}[\.]){3}[0-9]{1,3}[\/]{1}[0-9]{1,2}")
done
#if no ip after xy seconds "LED FAIL3
sendlog "recieved IP address from DHCP"

#scan
sendlog "starting stage 1"
LED STAGE1
#get internal connection info
echo "Date: ${date}" >> ${LOOT_DIR_NEW}/connection.txt
echo "Internal IP: ${SUBNET}" >> $LOOT_BASIC_PATH
LOOT_INT_GW:$(route | grep default | awk {'print $2'})
echo "Gateway IP: ${LOOT_INT_GW}" >> $LOOT_BASIC_PATH
LOOT_EXT_IP:$(curl $EXT_IP_PROV) || LED FAIL2 & sendlog "Failed to aquire external IP"
echo "External IP: ${LOOT_EXT_IP}" >> $LOOT_BASIC_PATH
sendlog "finished stage 1"

sendlog "starting stage 2"
LED STAGE2
nmap $NMAP_OPT $SUBNET -oN $LOOT_NMAP_PATH
sendlog "finished stage 2"

sendlog "payload finished"
LED FINISH
