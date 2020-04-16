export PATH=/home/$USER/.bin:$PATH
export PATH="/home/daniel/.yarn-global/bin/bin/firebase:$PATH"
# export PATH=/home/$USER/.yarn:$PATH
# export PATH=/usr/lib/jvm/java-11-openjdk/bin:$PATH
export EDITOR="nvim"
export PATH=~/.yarn-global/bin:$PATH
# export MSBuildSDKsPath=/opt/dotnet/sdk/$(dotnet --version)/Sdks
#export DOTNET_SKIP_FIRST_TIME_EXPERIENCE='True'
export PATH="$HOME/.rbenv/bin:$PATH"
export DOTNET_ROOT=/opt/dotnet
# export PATH="$PATH:/home/daniel/.dotnet/tools"
export XCURSOR_SIZE=10
export WORKON_HOME=~/.virtualenvs
export ANDROID_SDK_PATH=$HOME/Android/Sdk
export ANDROID_NDK_PATH=$HOME/Android/Sdk/ndk-bundle
export REACT_EDITOR=vscodium
export LESS='-R'
export LESSOPEN='|~/.bin/lessfilt.bin/lessfilter %s'


auto start startx.
if systemctl -q is-active graphical.target && [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi
