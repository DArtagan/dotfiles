#!/bin/bash
############################
# install.sh
# This script runs setup for certain personalizations including creating symlinks from the home directory to any desired dotfiles in ~/dotfiles
############################

########## Variables

gitdir=~/dotfiles                  # initial directory name after a git clone
dir=~/.dotfiles                    # dotfiles directory
olddir=~/.dotfiles_old             # old dotfiles backup directory
backupdir=~/.backup/vim-backup     # directory for vim backup files
swapdir=~/.backup/vim-swap         # directory for vim swap files
files="vimrc vim"                  # list of files/folders to symlink in homedir seperated by spaces

##########

# move the gitdir directory (dotfiles), that was cloned from git, to dir (.dotfiles) if it exists
if [ -d $gitdir ]; then
  mv $gitdir $dir
  echo "$gitdir moved to $dir"
else 
  echo "Could not find $gitdir, assuming the location is $dir."
fi 

# Runs solarize.sh to change the terminal theme to light, unless "dark" is specified as a parameter at the beginning.
if [ "$1" == "dark" ]; then
  $dir/solarize.sh dark
  echo "Dark theme set."
else 
  $dir/solarize.sh light
  echo "Light theme set."
fi

# Ensure the existance of a folder for vim backup and swap files 
if [ ! -d $backupdir ]; then
  mkdir -p $backupdir
  mkdir -p $swapdir
  echo "Vim backup and swap folder created at $backupdir."
else
  echo "Vim backup and swap folder already exists at $backupdir."
fi

# create dotfiles_old in homedir
echo "Creating $olddir for backup of any existing dotfiles in ~"
mkdir -p $olddir
echo "...done"

# change to the dotfiles directory
echo "Changing to the $dir directory"   
cd $dir
echo "...done"

# move any existing dotfiles in homedir to dotfiles_old directory, then create symlinks 
for file in $files; do
  echo "Moving any existing dotfiles from ~ to $olddir"
  mv ~/.$file $olddir
  echo "Creating symlink to $file in home directory."
  ln -s $dir/$file ~/.$file
done
