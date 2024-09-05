#remember that if more than one alias has the same name, the one that appear later is the one that will be used

# Check if oh-my-posh is available and set the flag
if command -v exa >/dev/null 2>&1; then
  USE_EXA=true
else
  USE_EXA=false
fi

alias a='alias'
alias aa='nice_print_aliases'
alias c='clear'
#alias cre="c && nice_print_aliases"
alias d='du -sh' # Prints disk usage of current folder in human readable form
alias df='df -h' # Prints disk usage in human readable form
alias edt='nano ~/.bashrc'
alias h='history'

#if you don't want to use exa disable the check at the start of the file or just set the USE_EXA to false in the shell
if [ "$USE_EXA" = true ]; then
    alias l='exa --long --all --group-directories-first --blocks --header --links --sort=name --icons --group --git'
else
    alias l='ls --color=auto -lAhv --group-directories-first' #-v is used for sort in natural form
fi

alias lx='exa --long --all --group-directories-first --blocks --header --links --sort=name --icons --group --git'
alias ll='ls --color=auto -lAhv --group-directories-first'

alias mount='mount |column -t' #Make mount command output pretty and human readable format
alias mp3dl='youtube-dl --extract-audio --audio-format mp3'
alias myip='curl -s http://ipecho.net/plain; echo' #the echo part is not really needed, plain curl should print to STDOUT anyway, -s stand for silent
alias n='nano -l'
alias nano='nano -l'
alias noh='cat /dev/null > ~/.bash_history'
alias rld="echo -e 'reloading .bashrc\n' && . ~/.bashrc"
alias update='sudo apt-get update && sudo apt-get upgrade -y'
alias wget='wget -c' #resume wget by default

#dockers
alias up_dockers='docker images | grep -v REPOSITORY | awk '\''{print $1}'\'' | xargs -L1 docker pull'
alias up_portainer_ce='docker pull portainer/portainer-ce:latest && docker stop portainer && docker rm portainer && docker run --name portainer -d -p 8000:8000 -p 9000:9000 -p 9443:9443 --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest --http-enabled'
alias up_portainer_be='docker pull portainer/portainer-ee:latest && docker stop portainer && docker rm portainer && docker run --name portainer -d -p 8000:8000 -p 9000:9000 -p 9443:9443 --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ee:latest --http-enabled'

#more useful bash aliases here: https://www.cyberciti.biz/tips/bash-aliases-mac-centos-linux-unix.html

#loading private aliases
if [ -f ~/.private_aliases ]; then
    . ~/.private_aliases
else
    touch . ~/.private_aliases
fi
