# dotfiles
my dotfiles across some pcs and my server

This will be personal, and messy, feel free to use, but i'm not so experienced in linux, i'm not responsible if something breaks
to use these files you need to copy them to your home or use ```setup.sh```, if you have no bashrc i will create one, but if you already have one you must (first time only) manually add lines below here to make your bashrc source my aliases

step by step:
```sh
git clone https://github.com/alsd4git/dotfiles
cd dotfiles
chmod +x setup.sh && sh setup.sh
```

if ```~/.bashrc``` is not present it will look like this: 
(also, these are the lines to add if you already have an existing .bashrc in your home dir)
```sh
. ~/.bash_aliases
. ~/.bash_functions
. ~/.git_aliases
. ~/.git_functions
. ~/.history_settings
. ~/.omp_init
. ~/.nanorc
nice_print_aliases
```

(also, optional, i like to have a screenfetch when i open my shell, so setup.sh will also add this line)

```sh
screenfetch 2>/dev/null && echo -e "\n"
```