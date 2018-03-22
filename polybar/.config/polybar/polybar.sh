#!/bin/bash
killall polybar

#Find all active monitors
connectedDisplays=$(xrandr | grep -E " connected (primary )?[1-9]+" | sed -e "s/\([A-Z0-9]\+\) connected.*/\1/")
echo Found $(echo $connectedDisplays | sed 's/ /\n/g' | wc -l) display\(s\): $connectedDisplays
#Take the first display to be the primary
mainMonitor=$(echo $connectedDisplays | awk '{print $1}')
echo Using $mainMonitor as primary display
MONITOR=$mainMonitor polybar main &> /dev/null &
secondaryDisplays=$(echo $connectedDisplays | sed 's/ /\n/g' | tail -n +2)
if [ ! -z "$secondaryDisplays" ]; then
    for display in $secondaryDisplays; do
        MONITOR=$display polybar secondary &> /dev/null &
        echo "Starting secondary polybar on $display"
    done
fi
