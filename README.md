# dotfiles
my dotfiles across some pcs and my server

this will be personal, and messy, feel free to use, but i'm not so experienced in linux, i'm not responsible if something breaks
to use these files you need to copy them to your home / use ```chmod a+x setup.sh && sh setup.sh```
and (atm) manually add these lines to your .bashrc / .profile to load them (```setup.sh``` will assume you have / will use a .bashrc)

step by step:
```sh
git clone http://github.com/alsd4git/dotfiles
cd dotfiles
chmod a+x setup.sh && sh setup.sh
```

```sh
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.bash_functions ]; then
    . ~/.bash_functions
fi
```

(also, optional, i like to have a screenfetch on my shell when i open, so setup.sh will also add this line)

```sh
screenfetch 2>/dev/null && echo -e "\n"
```