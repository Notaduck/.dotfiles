#!/bin/bash - 
#===============================================================================
#
#          FILE: git_notifications.sh
# 
#         USAGE: ./git_notifications.sh 
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

USER=$(jq -r '.user' ~/.config/github_notifications/init.json)
TOKEN=$(jq -r '.token' ~/.config/github_notifications/init.json)
RESPONSE=$(curl -s -u ${USER}:${TOKEN} https://api.github.com/notifications)
NUMBER_OF_NOTIFICATIONS=$(echo ${RESPONSE} | jq length)

if [ "$NUMBER_OF_NOTIFICATIONS" -eq "0" ]; then
	echo
else
	echo " $NUMBER_OF_NOTIFICATIONS"
fi
