#  ______ _____ _   _ ______  _____ 
# |___  //  ___| | | || ___ \/  __ \
#    / / \ `--.| |_| || |_/ /| /  \/
#   / /   `--. \  _  ||    / | |    
# ./ /___/\__/ / | | || |\ \ | \__/\
# \_____/\____/\_| |_/\_| \_| \____/
#

 # zmodload zsh/zprof
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
export LESS="-XRFS"
export PYENV_ROOT="$HOME/.pyenv"
# export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
# export PATH="$PYENV_ROOT/bin:$PATH"
# export PATH="$PATH:/home/daniel/.dotnet/tools"

export NPM_PACKAGES="${HOME}/.npm-packages"
export PATH="$PATH:$NPM_PACKAGES/bin"
export PATH=/home/$USER/.bin/blocks/:$PATH

# Preserve MANPATH if you already defined it somewhere in your config.
# Otherwise, fall back to `manpath` so we can inherit from `/etc/manpath`.
export MANPATH="${MANPATH-$(manpath)}:$NPM_PACKAGES/share/man"

# export NVM_DIR="$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# General settings {{{
#
	bindkey "^[[1;5C" forward-word
	bindkey "^[[1;5D" backward-word

	setopt autocd
	setopt automenu
	setopt histignorealldups
	setopt histignorespace
	setopt inc_append_history
	setopt listpacked
	setopt promptsubst
	setopt share_history

	HISTFILE=~/.histfile
	HISTSIZE=5000
	SAVEHIST=5000

	bindkey -v
	bindkey '^R' history-incremental-search-backward

	autoload -U colors && colors # Enable colors
	autoload -Uz compinit

	if [[ -n ${ZDOTDIR}/.zcompdump(#qN.mh+24) ]]; then
		compinit;
	else
		compinit -C;
	fi;

	zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
	zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
	zstyle ':completion:*' menu select
	zstyle ':completion:*' special-dirs true

	zmodload zsh/complist
	compinit -i


	function zle-keymap-select zle-line-init zle-line-finish {
		case $KEYMAP in
			vicmd)      print -n -- "\E]50;CursorShape=0\C-G";; # block cursor
			viins|main) print -n -- "\E]50;CursorShape=1\C-G";; # line cursor
		esac

		zle reset-prompt
		zle -R
	}

	zle -N zle-line-init
	zle -N zle-line-finish
	zle -N zle-keymap-select

# }}}

# zplugin {{{
	 source ~/.zplugin/bin/zplugin.zsh

	 zplugin light zsh-users/zsh-completions
	 zplugin light zsh-users/zsh-autosuggestions

	 zplugin snippet OMZ::plugins/git/git.plugin.zsh
	 zplugin snippet OMZ::lib/git.zsh
	 zplugin snippet OMZ::themes/theunraveler.zsh-theme

	 zplugin ice wait lucid
	 zplugin snippet OMZ::plugins/colored-man-pages/colored-man-pages.plugin.zsh

# }}}

# Include {{{
	[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"
# }}}

 # zprof
