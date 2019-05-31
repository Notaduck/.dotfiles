# Variables
TERM='st'
IRC_CLIENT='weechat'

# lock after 5 min
# xautolock -time 5 -locker 'betterlockscreen -l' 

# Launch weechat
# $TERM -n $IRC_CLIENT -c $IRC_CLIENT 

# Start the gnome-keyring-daemon
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)
export SSH_AUTH_SOCK


# set the background
feh --bg-fill ~/Pictures/Wallpaper/forrest.jpg 

# Start pulseadui in order to get my headset workin
pulseaduio --start

# set the layout to be danish and map capslock to escape
setxkbmap -model dell -layout dk -option caps:escape 

# Touchpad settings
xinput set-prop "DLL06E4:01 06CB:7A13 Touchpad" "libinput Tapping Enabled" 1 
xinput set-prop "DLL06E4:01 06CB:7A13 Touchpad" "libinput Natural Scrolling Enabled" 1 

function WIFI()
{
  INTERFACE="wlp2s0"
	NETWORK=$(iwconfig $INTERFACE | grep -oP "ESSID:\K(.*)" | sed -e 's/"//g')

	if [[ $NETWORK = *"off/any"* ]]; then
		echo "  not connected"
  else
		echo " " $NETWORK " "
	fi

}

function DATE() 
{
	echo "$( date +"%F %R " )" 
}

while true; do
   xsetroot -name "$( DATE ) $( WIFI )"
   sleep 5s    # Update time every minute
done &

# exec dwm
while :; do
		ssh-agent dwm
done

# Launxh nextcloud in the background
exec nextcloud --background
