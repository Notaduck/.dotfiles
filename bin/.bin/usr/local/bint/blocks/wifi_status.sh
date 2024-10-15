#!/bin/bash - 
#===============================================================================
#
#          FILE: wifi_status.sh
# 
#         USAGE: ./wifi_status.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 2020-06-10 12:43
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

INTERFACE="wlp2s0"
NETWORK=$(iwconfig $INTERFACE | grep -oP "ESSID:\K(.*)" | sed -e 's/"//g' | trim)

if [[ $NETWORK == *"off/any"* ]]; then
	echo "not connected "
else
	echo " $NETWORK"
fi


