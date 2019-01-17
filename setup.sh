copy_with_backup(){
#based on https://stackoverflow.com/questions/10204562/difference-between-if-e-and-if-f
    if [ -e ~/"$1" ]; then
        #passed file exists
        if  ! cmp -s ~/"$1" "$1" ; then
            #files are different
            mv  ~/"$1"  ~/old_"$1"_$(date +'%m.%d.%Y_%H.%M.%S').bak
            echo -e "backed up: ~/"$1" \tto: ~/old_"$1"_$(date +'%m.%d.%Y_%H.%M.%S').bak"
        else
            echo -e $1"\tis already updated"
        fi
    fi
    cp "$1" ~/
}

add_to_bashrc_if_not_present(){
#based on https://stackoverflow.com/questions/4749330/how-to-test-if-string-exists-in-file-with-bash
    if grep -Fq "$1" ~/.bashrc; then
        echo $1 " found, no need to add"
    else
        echo "adding "$1
        echo $1 >> ~/.bashrc
    fi
}

#chown --reference=~/.bashrc .bash_aliases
#chmod --reference=~/.bashrc .bash_aliases

if [ -f ~/.bashrc ]; then
    echo ".bashrc present, i will only add needed lines"
    # here we add bash_aliases loading
    add_to_bashrc_if_not_present  ". ~/.bash_functions"
    add_to_bashrc_if_not_present  ". ~/.bash_aliases"
    add_to_bashrc_if_not_present  ". ~/.git_aliases"
    add_to_bashrc_if_not_present  "nice_print_aliases"
    add_to_bashrc_if_not_present  "screenfetch 2>/dev/null"
else
    # whole new file, need to add bash_aliases loading
    echo ".bashrc not found, i will create one in your profile directory and add alias sourcing to it"
    touch . ~/.bashrc
    echo ". ~/.bash_functions" >> ~/.bashrc
    echo ". ~/.bash_aliases"   >> ~/.bashrc
    echo ". ~/.git_aliases"    >> ~/.bashrc
    echo "nice_print_aliases"  >> ~/.bashrc
    echo "screenfetch 2>/dev/null" >> ~/.bashrc
fi
echo "i will now copy new files, backing up the old ones (only for changed/updated files)"
copy_with_backup .bash_aliases
copy_with_backup .bash_functions
copy_with_backup .git_aliases
copy_with_backup .nanorc
echo "you can type 'rm  ~/old_*.bak' to get rid of all old backups"
