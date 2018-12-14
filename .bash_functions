function ren_pics(){
cur_dir=$(basename "$PWD") && exiv2 -r"$cur_dir"' - %Y-%m-%d %H.%M.%S' -F rename *;
}

function nice_print_aliases(){
#with sed to replace all occurences you have to add a g before last single quote
echo -e "Aliases List:\n" && alias  | GREP_COLOR='01;32' egrep --color=always 'alias|' | GREP_COLOR='01;32' egrep --color=always 'git|' | sed 's/\=/ \t/' && echo -e "\n"
#echo -e "Lista Alias:\n" && alias  | GREP_COLOR='01;32' egrep --color=always 'alias|' | GREP_COLOR='01;32' egrep --color=always 'git|' | sed 's/\=/ \t/' && echo -e "\n"
}
export -f nice_print_aliases
