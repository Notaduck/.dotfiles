#  ______ _____ _   _ ______  _____ 
# |___  //  ___| | | || ___ \/  __ \
#    / / \ `--.| |_| || |_/ /| /  \/
#   / /   `--. \  _  ||    / | |    
# ./ /___/\__/ / | | || |\ \ | \__/\
# \_____/\____/\_| |_/\_| \_| \____/
source /usr/bin/virtualenvwrapper.sh
# set JAVA_OPTS=-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee
#
# General settings {{{

	setopt listpacked
	setopt automenu
	setopt autocd
	setopt histignorealldups
	setopt histignorespace
	setopt inc_append_history
	setopt share_history
	setopt promptsubst

	HISTFILE=~/.histfile
	HISTSIZE=5000
	SAVEHIST=5000
	
	autoload -U colors && colors # Enable colors
	autoload -U compinit

	zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
	zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
	zstyle ':completion:*' menu select
	zstyle ':completion:*' special-dirs true
	zmodload zsh/complist
	compinit -i

# }}}

# zplugin {{{
	source ~/.zplugin/bin/zplugin.zsh

	# zplugin cdclear -q # <- forget completions provided by Git plugin
	#
	# | completions | #
	# zplugin ice wait'!1'
	zplugin light zsh-users/zsh-completions
	zplugin light zsh-users/zsh-autosuggestions
	zplugin snippet OMZ::plugins/git/git.plugin.zsh


	zplugin snippet OMZ::plugins/git/git.plugin.zsh
	zplugin snippet http://github.com/robbyrussell/oh-my-zsh/raw/master/lib/git.zsh

	zplugin snippet OMZ::themes/theunraveler.zsh-theme
	zplugin ice wait lucid
	zplugin snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

# }}}

# Functions {{{
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
# }}}
 
# OH MY ZHS {{{
  # ZSH_THEME="theunraveler"

 # plugins=(
 # 				 git 
 # 				 zsh-autosuggestions
 # 				 colored-man-pages
 # 			  )

 # source $ZSH/oh-my-zsh.sh
# }}}

# Include {{{
	[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"
# }}}

