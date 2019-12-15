export XCURSOR_SIZE=10
export WORKON_HOME=~/.virtualenvs
# source /usr/bin/virtualenvwrapper.sh
export ANDROID_SDK_PATH=$HOME/Android/Sdk
export ANDROID_NDK_PATH=$HOME/Android/Sdk/ndk-bundle
export REACT_EDITOR=vscodium
set JAVA_OPTS=-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee

function countdown(){
   date1=$((`date +%s` + $1)); 
   while [ "$date1" -ge `date +%s` ]; do 
     echo -ne "$(date -u --date @$(($date1 - `date +%s`)) +%H:%M:%S)\r";
     sleep 0.1
   done
}

function stopwatch(){
  date1=`date +%s`; while true; do 
    echo -ne "$(date -u --date @$((`date +%s` - $date1)) +%H:%M:%S)\r"; 
    sleep 0.1
   done
}

######## OH MY ZHS ###############

ZSH_THEME="theunraveler"

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#
plugins=(
				 git 
				 zsh-autosuggestions
				 colored-man-pages
			  )

source $ZSH/oh-my-zsh.sh


##################################

alias weather="curl wttr.in"
alias vim="nvim"
alias code="codium"
alias cat="bat"
alias def="definition"
alias cclip='xclip -selection clipboard'
alias tb="nc termbin.com 9999"
# Alias automaticly copy the URL to the cliptboard
alias tbc="netcat termbin.com 9999 | xclip -selection c"
alias itu='cd /home/daniel/Nextcloud/Skole/ITU/5_Semester'
alias IDB='cd /home/daniel/Nextcloud/Skole/ITU/5_Semester/IDB'
alias BDSA='cd /home/daniel/Nextcloud/Skole/ITU/5_Semester/BDSA'
