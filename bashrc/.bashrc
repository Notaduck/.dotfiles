#
# ~/.bashrc
#

[[ $- != *i* ]] && return

colors() {
    local fgc bgc vals seq0

    printf "Color escapes are %s\n" '\e[${value};...;${value}m'
    printf "Values 30..37 are \e[33mforeground colors\e[m\n"
    printf "Values 40..47 are \e[43mbackground colors\e[m\n"
    printf "Value  1 gives a  \e[1mbold-faced look\e[m\n\n"
    
    # foreground colors
    for fgc in {30..37}; do
        # background colors
        for bgc in {40..47}; do
            fgc=${fgc#37} # white
            bgc=${bgc#40} # black

            vals="${fgc:+$fgc;}${bgc}"
            vals=${vals%%;}

            seq0="${vals:+\e[${vals}m}"
            printf "  %-9s" "${seq0:-(default)}"
            printf " ${seq0}TEXT\e[m"
            printf " \e[${vals:+${vals+$vals;}}1mBOLD\e[m"
        done
        echo; echo
    done
}

[[ -f ~/.extend.bashrc ]] && . ~/.extend.bashrc

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion

# display a fortune
#fortune -s -n 120 wisdom linux computers science
#echo "-----------------------------------------"
#echo

# alias aliasname='commands'
alias itu="cd ~/Nextcloud/Skole/ITU/2.\ Semester"

# `cclip' copies and `clipp' pastes'
alias cclip='xclip -selection clipboard'
alias clipp='xclip -selection clipboard -o'

# Default text editor
export EDITOR='nvim'
export VISUAL='nvim'

# ITU Stuff
export PATH=$PATH:$HOME/algs4/bin

# add npm to work global
export PATH=~/.npm-global/bin:$PATH
export PATH=$PATH:~/.yarn/bin

export PATH="${PATH}:${HOME}/.local/bin/"

# entity framework tool for c#
export PATH="$PATH:/root/.dotnet/tools"


[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Function to get the current git banch
git_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

#export PS1="\[\033[01;32m\][\u@\h\[\033[01;37m\] \W\[\033[01;32m\]]\$(git_branch)\[\033[66m\]\$ \[\033[00m\]" 


