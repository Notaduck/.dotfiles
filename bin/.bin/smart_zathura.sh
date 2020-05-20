#!/bin/bash - 
#===============================================================================
#
#          FILE: smat-zathura.sh
# 
#         USAGE: ./smat-zathura.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 2020-05-01 13:17
#      REVISION:  ---
#===============================================================================

# set -o nounset                              # Treat unset variables as an error

if [ -z "$1" ]
  then
		tabbed zathura -e &
else
	tabbed zathura $(pwd)/$1 -e &
fi

