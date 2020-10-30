#!/bin/bash - 
#===============================================================================
#
#          FILE: set_keyboard_layout.sh
# 
#         USAGE: ./set_keyboard_layout.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 2020-10-02 11:25
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

setxkbmap -query | grep -q 'us' && setxkbmap dk || setxkbmap us; pkill -RTMIN+1 dwmblocks

