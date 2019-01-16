function ren_pics(){
    cur_dir=$(basename "$PWD") && exiv2 -r"$cur_dir"' - %Y-%m-%d %H.%M.%S' -F rename *;
}

function nice_print_aliases(){
    if [ "$(locale | grep LANG | cut -d= -f2 | cut -d_ -f1)" = "it" ]; then
        #echo "ita"
        echo -e  "Lista Alias:\n"
    else
        #echo "no ita"
        echo -e "Aliases List:\n"
    fi

    #with sed to replace all occurences you have to add a g before last single quote
    alias | GREP_COLOR='01;32' grep -E --color=always 'alias |git' | sed 's/\=/ \t/'
}
export -f nice_print_aliases

function nanobk() {
    echo "You are making a copy of $1 before you open it. Press enter to continue."
    read nul
    cp $1 $1.bak
    nano $1
}

function nbk(){
    nanobk $1
}

#a useful cheatsheet online: https://devhints.io/bash
#export is used to make functions usable by subshells, add it if you need to, i may add it in future
