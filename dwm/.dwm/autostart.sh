#!/bin/env sh
TERM="st"

compton --config ~/.config/compton.conf &
feh --no-xinerama --bg-scale  ~/.i3/wallpaper/forrest.jpg &
${TERM} -n "weechat" -e "weechat" &
unclutter --exclude-root --ignore-scrolling -keystroke -idle 15 &
 
