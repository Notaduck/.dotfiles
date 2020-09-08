#!/bin/bash - 
#===============================================================================
#
#          FILE: battery.sh
# 
#         USAGE: ./battery.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 2020-06-10 11:51
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

CAPASITY=$(cat /sys/class/power_supply/BAT0/capacity)
STATE=$(cat /sys/class/power_supply/BAT0/status)

if [[ $STATE == 'Discharging' ]]; then
	if ((CAPASITY >= 95)); then
		echo " $CAPASITY%"
	elif ((CAPASITY >= 75)); then
		echo " $CAPASITY%"
	elif ((CAPASITY >= 50)); then
		echo " $CAPASITY%"
	elif ((CAPASITY >= 5)); then
		echo " $CAPASITY%"
	else
		echo " $CAPASITY"
	fi
else
	echo " $CAPASITY%"
fi

