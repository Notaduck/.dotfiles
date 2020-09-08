#!/bin/bash - 
#===============================================================================
#
#          FILE: kb_layout.sh
# 
#         USAGE: ./kb_layout.sh 
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

LANGUAGE=$(xkb-switch)
echo " $LANGUAGE "

