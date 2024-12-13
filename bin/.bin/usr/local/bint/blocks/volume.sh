#!/bin/bash - 
#===============================================================================
#
#          FILE: volume.sh
# 
#         USAGE: ./volume.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 2020-06-10 12:42
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

vol=$(
	amixer -D pulse sget Master | grep 'Left:' | awk -F'[][]' '{ print $2 }' | grep -Eo "[0-9]{1,3}" | trim
)
STATUS=$(pactl list sinks | grep -oP "Mute: \K\w+")
if [[ $STATUS == *"yes"* ]]; then
	echo " "
else
	if ((vol > 50)); then
		echo " $vol%"
	elif ((vol > 1)); then
		echo " $vol%"
	else
		echo " $vol%"
	fi
fi

