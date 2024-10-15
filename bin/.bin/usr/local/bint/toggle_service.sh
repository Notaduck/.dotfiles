#!/bin/bash - 
#===============================================================================
#
#          FILE: toggle_service.sh
# 
#         USAGE: ./toggle_service.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 2019-10-26 22:35
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error
set -x
#!/bin/bash
if pgrep -x $1 >/dev/null
then
	killall $1
else
		nohup $1 &
fi

