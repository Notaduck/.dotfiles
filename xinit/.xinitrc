#!/bin/zsh

# Create the logs directory if it doesn't exist
mkdir -p ~/.logs

# Variables
export TERMINAL='alacritty'
export _JAVA_AWT_WM_NONREPARENTING=1

LAPTOPKEYBOARD=$(xinput --list --id-only 'AT Translated Set 2 keyboard' 2>~/.logs/xinput.log)

# Start the gnome-keyring-daemon
eval $(/usr/bin/gnome-keyring-daemon --start --components=pkcs11,secrets,ssh 2>~/.logs/gnome-keyring-daemon.log)
export SSH_AUTH_SOCK
source /etc/X11/xinit/xinitrc.d/50-systemd-user.sh 2>~/.logs/systemd-user.log

sxhkd > ~/.logs/sxhkd.log 2>&1 &
nm-applet > ~/.logs/nm-applet.log 2>&1 &
unclutter --timeout 10 --jitter 3 > ~/.logs/unclutter.log 2>&1 &
greenclip daemon &

# Lock after 5 min, corners is tp,tr.bl.br
xautolock -time 10 -locker 'betterlockscreen -l' > ~/.logs/xautolock.log 2>&1 &

xrandr --setprovideroutputsource modesetting NVIDIA-0 > ~/.logs/xrandr.log 2>&1 &

# Check if HDMI-1 is connected
if xrandr | grep -q "HDMI-1 connected"; then
    # Extract EDID hex block and search for model number 30510 (encoded in hex)
    # The product ID for model 30510 in hexadecimal is 772e
    EDID_HEX=$(xrandr --verbose | grep -A 16 "HDMI-1" | grep -E -o "00ffffffffffff00.*")

    # Check if the EDID contains the model number (30510) encoded as '772e'
    if [[ "$EDID_HEX" == *"772e"* ]]; then
        # Load saved ARandR layout for home (assuming this is the LG HDR WQHD)
        ~/.screenlayout/home.sh > ~/.logs/screenlayout.log 2>&1 &
    else
        echo "The connected monitor is not the LG HDR WQHD (Model 30510)" > ~/.logs/monitor-check.log
    fi
else
    # Load a different layout or use default xrandr setup
    xrandr --output eDP-1 --auto --output HDMI-1 --off --output DP-2 --off > ~/.logs/xrandr-auto.log 2>&1 &
fi

# Set the background
feh --bg-scale --no-xinerama ~/.wallpapers/man-on-the-moon.jpg> ~/.logs/feh.log 2>&1

# Set the layout to be Danish and map Caps Lock to Escape, and swap Super <--> Alt
setxkbmap -device $LAPTOPKEYBOARD -model dell -layout dk -option "caps:escape, altwin:swap_lalt_lwin" > ~/.logs/setxkbmap.log 2>&1 &

# Touchpad settings
xinput set-prop "DLL06E4:01 06CB:7A13 Touchpad" "libinput Tapping Enabled" 1 > ~/.logs/touchpad.log 2>&1
xinput set-prop "DLL06E4:01 06CB:7A13 Touchpad" "libinput Natural Scrolling Enabled" 1 >> ~/.logs/touchpad.log 2>&1

libinput-gestures-setup start > ~/.logs/libinput-gestures.log 2>&1

dwmbar > ~/.logs/dwmbar.log 2>&1 &
# dwmblocks > ~/.logs/dwmblocks.log 2>&1 &

# Exec dwm
while :; do
    ssh-agent dwm > ~/.logs/dwm.log 2>&1
done
