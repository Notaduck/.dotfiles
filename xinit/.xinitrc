# Variables
export TERMINAL='st'
export IRC_CLIENT='weechat'
LAPTOPKEYBOARD=$( xinput --list --id-only 'AT Translated Set 2 keyboard')

# Start the gnome-keyring-daemon
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
source /etc/X11/xinit/xinitrc.d/50-systemd-user.sh 

# Universal key bindings
sxhkd &

# Hide the cursor after 10 sec
unclutter --timeout 10 --jitter 3 &

# lock after 5 min
xautolock -time 5 -locker 'betterlockscreen -l' &

# Launch weechat
$TERMINAL -n $IRC_CLIENT -e $IRC_CLIENT &

# set the background
feh --bg-fill ~/Pictures/Wallpaper/forrest.jpg &

# Start pulseadui in order to get my headset workin
pulseaduio --start &

# set the layout to be danish and map capslock to escape, and swap super <--> alt
setxkbmap -device $LAPTOPKEYBOARD -model dell -layout dk -option "caps:escape, altwin:swap_lalt_lwin" &

# Launxh nextcloud in the background
exec nextcloud --background &

# Touchpad settings
xinput set-prop "DLL06E4:01 06CB:7A13 Touchpad" "libinput Tapping Enabled" 1 
xinput set-prop "DLL06E4:01 06CB:7A13 Touchpad" "libinput Natural Scrolling Enabled" 1 

function BATT(){

	CAPASITY=$(cat /sys/class/power_supply/BAT0/capacity)
	STATE=$(cat /sys/class/power_supply/BAT0/status)

	if [[ STATE='Dischargin' ]]; then
		if (( $CAPASITY >= 95 )); then
			echo " $CAPASITY%"
		elif (( CAPASITY >= 75 )); then
			echo " $CAPASITY%"
		elif (( CAPASITY >= 50 )); then
			echo " $CAPASITY%"
		elif (( CAPASITY >= 5 )); then
			echo " $CAPASITY%"
		else 
			echo " $CAPASITY%"
		fi
	else
			echo " $CAPASITY%"
	fi

}

function WIFI()
{
  INTERFACE="wlp2s0"
	NETWORK=$(iwconfig $INTERFACE | grep -oP "ESSID:\K(.*)" | sed -e 's/"//g')

	if [[ $NETWORK = *"off/any"* ]]; then
		echo " not connected " 
  else
		echo " " $NETWORK 
	fi

}

function DATE() 
{
	echo "$( date +"%F %R " )" 
}

function LAYOUT()
{
	LANGUAGE=$(setxkbmap -query | grep layout | awk '{print $2}')
	echo " $LANGUAGE"
}
while true; do
   xsetroot -name "$(LAYOUT) $(DATE) $(WIFI) $(BATT) "
   sleep 2s    # Update time every minute
done &

# exec dwm
while :; do
		ssh-agent dwm
done

