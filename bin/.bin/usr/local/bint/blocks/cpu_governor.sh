#!/bin/bash - 
#===============================================================================
#
#          FILE: time.sh
# 
#         USAGE: ./time.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 2020-06-10 11:36
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error
GOVERNOR=$(cat /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor)

if [[ $GOVERNOR == 'powersave' ]]; then
	echo "cpu: $GOVERNOR"  # missing icons
else
	echo "cpu: $GOVERNOR" 
fi
