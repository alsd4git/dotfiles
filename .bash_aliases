#remember that if more than one alias has the same name, the one that appear later is the one that will be used

export LS_OPTIONS='--color=auto'
alias ..='cd ..'
alias a='alias'
alias c='clear'
alias cd..='cd ..'
alias cre="c && nice_print_aliases"
alias d='du -sh' # Prints disk usage of current folder in human readable form
alias df='df -h' # Prints disk usage in human readable form
alias edt='nano ~/.bashrc'
alias h='history'
alias l='ls $LS_OPTIONS -lAhv --group-directories-first' #-v is used for sort in natural form
alias mount='mount |column -t' #Make mount command output pretty and human readable format
alias mp3dl='youtube-dl --extract-audio --audio-format mp3'
alias myip='curl -s http://ipecho.net/plain; echo' #the echo part is not really needed, plain curl should print to STDOUT anyway, -s stand for silent
alias n='nano -l'
alias nano='nano -l'
alias noh='cat /dev/null > ~/.bash_history'
alias rld="echo -e 'reloading .bashrc\n' && . ~/.bashrc"
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias wget='wget -c' #resume wget by default

#more useful bash aliases here: https://www.cyberciti.biz/tips/bash-aliases-mac-centos-linux-unix.html

#loading private aliases
if [ -f ~/.private_aliases ]; then
    . ~/.private_aliases
else
    touch . ~/.private_aliases
fi
