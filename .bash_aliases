#remember that if more than one alias has the same name, the one that appear later is the one that will be used

export LS_OPTIONS='--color=auto'
alias l='ls $LS_OPTIONS -lAh --group-directories-first'
alias n='nano -l'
alias nano='nano -l'
alias ..='cd ..'
alias cd..='cd ..'
alias c='clear'
alias edt='nano ~/.bashrc'
alias noh='cat /dev/null > ~/.bash_history'
alias update='sudo apt-get update && sudo apt-get upgrade'

#loading private aliases
if [ -f ~/.private_aliases ]; 
then
    . ~/.private_aliases
else
	touch . ~/.private_aliases
fi

#loading more aliases
if [ -f ~/.git_aliases ]; 
then
    . ~/.git_aliases
fi