#!/bin/env sh
TERM="termite"

compton --config ~/.config/compton.conf &
feh --no-xinerama --bg-scale  ~/.i3/wallpaper/forrest.jpg &
${TERM} --name="weechat" --exec=weechat &
unclutter -keystroke -idle 15 &
xsetroot -name "$(info.sh)" &
 
