export PATH=/home/$USER/.bin:$PATH
export PATH=/usr/lib/jvm/java-11-openjdk/bin:$PATH
export PATH=~/.yarn-global/bin:$PATH
# export MSBuildSDKsPath=/opt/dotnet/sdk/$(dotnet --version)/Sdks
export PATH="$HOME/.rbenv/bin:$PATH"

export XCURSOR_SIZE=10
export WORKON_HOME=~/.virtualenvs
export ANDROID_SDK_PATH=$HOME/Android/Sdk
export ANDROID_NDK_PATH=$HOME/Android/Sdk/ndk-bundle
export REACT_EDITOR=vscodium


# auto start startx.
if systemctl -q is-active graphical.target && [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi
