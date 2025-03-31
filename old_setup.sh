copy_with_backup() {
    # $1 = source path
    # $2 = destination filename (optional, defaults to basename of $1)
    dest_name="${2:-$(basename "$1")}"
    if [ -e ~/"$dest_name" ]; then
        # File exists in home
        if ! cmp -s ~/"$dest_name" "$1"; then
            # Files differ
            mv ~/"$dest_name" ~/old_"$dest_name"_$(date +'%m.%d.%Y_%H.%M.%S').bak
            echo -e "backed up: ~/$dest_name \tto: ~/old_${dest_name}_$(date +'%m.%d.%Y_%H.%M.%S').bak"
        else
            echo -e "$dest_name is already updated"
        fi
    fi
    cp "$1" ~/"$dest_name"
}

add_to_bashrc_if_not_present() {
    #based on https://stackoverflow.com/questions/4749330/how-to-test-if-string-exists-in-file-with-bash
    if grep -Fq "$1" ~/.bashrc; then
        echo $1 " found, no need to add"
    else
        echo "adding "$1
        echo $1 >>~/.bashrc
    fi
}

#chown --reference=~/.bashrc .bash_aliases
#chmod --reference=~/.bashrc .bash_aliases

if [ -f ~/.bashrc ]; then
    echo ".bashrc present, i will only add needed lines"
    # here we add bash_aliases loading
    add_to_bashrc_if_not_present ". ~/.bash_aliases"
    add_to_bashrc_if_not_present ". ~/.bash_functions"
    add_to_bashrc_if_not_present ". ~/.git_aliases"
    add_to_bashrc_if_not_present ". ~/.git_functions"
    add_to_bashrc_if_not_present ". ~/.history_settings"
    add_to_bashrc_if_not_present ". ~/.omp_init"
    add_to_bashrc_if_not_present "nice_print_aliases"
    add_to_bashrc_if_not_present "screenfetch 2>/dev/null"
else
    # whole new file, need to add bash_aliases loading
    echo ".bashrc not found, i will create one in your profile directory and add alias sourcing to it"
    touch . ~/.bashrc
    echo ". ~/.bash_aliases" >>~/.bashrc
    echo ". ~/.bash_functions" >>~/.bashrc
    echo ". ~/.git_aliases" >>~/.bashrc
    echo ". ~/.git_functions" >>~/.bashrc
    echo ". ~/.history_settings" >>~/.bashrc
    echo ". ~/.omp_init" >>~/.bashrc
    echo "nice_print_aliases" >>~/.bashrc
    echo "screenfetch 2>/dev/null" >>~/.bashrc
fi
echo "i will now copy new files, backing up the old ones (only for changed/updated files)"
copy_with_backup general/.aliases .bash_aliases
copy_with_backup general/.functions .bash_functions
copy_with_backup git/.git_aliases .git_aliases
copy_with_backup git/.git_functions .git_functions
copy_with_backup general/.history_settings .history_settings
copy_with_backup general/.omp_init .omp_init
copy_with_backup nano/.nanorc .nanorc
echo "you can type 'rm  ~/old_*.bak' to get rid of all old backups"
