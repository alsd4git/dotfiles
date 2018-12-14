#chown --reference=~/.bashrc .bash_aliases
#chmod --reference=~/.bashrc .bash_aliases

#chown --reference=~/.bashrc .bash_functions
#chmod --reference=~/.bashrc .bash_functions

#chown --reference=~/.bashrc .git_aliases
#chmod --reference=~/.bashrc .git_aliases
if [ -f ~/.bashrc ]; 
	then 
		echo "please manually add alias loading, instruction in README.md";
		# here we add bash_aliases loading
	else
		# whole new file, need to add bash_aliases loading
		touch . ~/.bashrc;
		echo ". ~/.bash_functions">>~/.bashrc;
		echo ". ~/.bash_aliases">>~/.bashrc;
		echo "screenfetch 2>/dev/null && echo -e '\n'">>~/.bashrc;
fi
echo "press y + enter for every file to copy them (if asked)"
cp -i .bash_aliases .bash_functions .git_aliases ~/
