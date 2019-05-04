#!/bin/env sh
DATE(){
	command date +"%H:%M %a %d/%m-%y"
}

BATT(){
	hash acpi || return 0
		charge="$(awk '{ sum += $1 } END { print sum }' /sys/class/power_supply/BAT*/capacity)"
			# On mains! no need to suspend
			#systemctl --user start inhibit-lid-sleep-on-battery.service
			echo -e "  ${charge}% "
}

TERM="st"

compton --config ~/.config/compton.conf &
xautolock -time 10 -locker 'betterlockscreen -l' &
feh --no-xinerama --bg-scale  ~/.i3/wallpaper/forrest.jpg &
${TERM} -n "weechat" -e "weechat" &
unclutter --exclude-root --ignore-scrolling -keystroke -idle 15 &


while true
do
	xsetroot -name " $(DATE) $(BATT) "
	sleep 1m
done 
