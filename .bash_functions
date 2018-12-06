function ren_pics(){
cur_dir=$(basename "$PWD") && exiv2 -r"$cur_dir"' - %Y-%m-%d %H.%M.%S' -F rename *;
}

function nice_print_aliases(){
echo -e "Aliases List:\n" && alias  | GREP_COLOR='01;32' egrep --color=always 'alias|' | GREP_COLOR='01;32' egrep --color=always 'git|' | sed 's/\=/ \t/g' && echo -e "\n"
#echo -e "Lista Alias:\n" && alias  | GREP_COLOR='01;32' egrep --color=always 'alias|' | GREP_COLOR='01;32' egrep --color=always 'git|' | sed 's/\=/ \t/g' && echo -e "\n"
}
export -f nice_print_aliases
