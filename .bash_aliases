#remember that if more than one alias has the same name, the one that appear later is the one that will be used

export LS_OPTIONS='--color=auto'
alias l='ls $LS_OPTIONS -lAh --group-directories-first'
alias n='nano -l'
alias nano='nano -l'
alias ..='cd ..'
alias cd..='cd ..'
alias c='clear'
alias cre="c && nice_print_aliases"
alias d='du -sh' # Prints disk usage in human readable form
alias edt='nano ~/.bashrc'
alias h='history'
alias mount='mount |column -t' #Make mount command output pretty and human readable format
alias noh='cat /dev/null > ~/.bash_history'
alias wget='wget -c' #resume wget by default
alias update='sudo apt-get update && sudo apt-get upgrade'

#more useful bash aliases here: https://www.cyberciti.biz/tips/bash-aliases-mac-centos-linux-unix.html

#loading private aliases
if [ -f ~/.private_aliases ]; 
then
    . ~/.private_aliases
else
	touch . ~/.private_aliases
fi
