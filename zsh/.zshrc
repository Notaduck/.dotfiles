#  ______ _____ _   _ ______  _____ 
# |___  //  ___| | | || ___ \/  __ \
#    / / \ `--.| |_| || |_/ /| /  \/
#   / /   `--. \  _  ||    / | |    
# ./ /___/\__/ / | | || |\ \ | \__/\
# \_____/\____/\_| |_/\_| \_| \____/
# source /usr/bin/virtualenvwrapper.sh
# set JAVA_OPTS=-XX:+IgnoreUnrecognizedVMOptions --add-modules java.se.ee
#
#  General settings {{{
	setopt inc_append_history
	setopt share_history
	setopt promptsubst
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

# zplugin {{{
	source ~/.zplugin/bin/zplugin.zsh

zplugin snippet OMZ::plugins/git/git.plugin.zsh
zplugin cdclear -q # <- forget completions provided by Git plugin
	# | completions | #
	# zplugin ice wait'!1'
	# zplugin light zsh-users/zsh-completions
	# zplugin light zsh-users/zsh-autosuggestions
	#
	source ~/.zplugin/plugins/zsh-users---zsh-autosuggestions/zsh-autosuggestions.zsh

	# /zsh-autosuggestions.plugin.zsh

	autoload -U colors && colors # Enable colors
	HISTFILE=~/.histfile
	HISTSIZE=1000
	SAVEHIST=1000
	# setopt appendhistory
	# Two regular plugins loaded without tracking.
	# zplugin light zsh-users/zsh-autosuggestions
	zplugin snippet OMZ::plugins/git/git.plugin.zsh
	zplugin snippet http://github.com/robbyrussell/oh-my-zsh/raw/master/lib/git.zsh

	zplugin snippet OMZ::themes/theunraveler.zsh-theme
	zplugin ice wait lucid
	zplugin snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

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
#
zstyle ':completion:*' list-colors "${(@s.:.)LS_COLORS}"
autoload -Uz compinit
compinit
