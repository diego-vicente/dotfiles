#!/bin/bash

# First of all, install homebrew
/usr/bin/ruby -e "$(curl -fsSL \
    https://raw.githubusercontent.com/Homebrew/install/master/install)"

# Install homebrew cask for heavyweight apps
brew tap caskroom cask

# ===============================[ TERMINAL ]==================================
# zsh as the default shell
chsh -s $(which zsh)
# Install oh-my-zsh
sh -c "$(curl -fsSL \
    https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
# Set the correct .zshrc file
cp zshrc ~/.zshrc
source ~/.zshrc

# Override default vim with macvim
brew install macvim  --override-system-vim
# Set the correct .vimrc file
cp vimrc ~/.vimrc
# Set up Vundle
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
# Install all the sweet plugins
vim +PluginInstall +qall

# Install iTerm2
brew cask install iterm2

# ================================[ OTHER ]====================================

# Other things to install
brew install imagemagick
sudo gem install lolcommits
brew cask install typora
brew cask install lacona
brew cask install the-unarchiver
brew cask install flux
brew cask install beardedspice

# ============================[ SET THINGS UP ]================================

# ============================[ LAST REMINDER ]================================
cat << EOF
There are some things that you still don't know how to configure/install using
a script. Nevertheless, here you have a list of things to now that the initial
configuration is complete:
    [] Install some of your everyday apps using Mac App Store: Fantastical,
       Telegram, Tweetbot, 
