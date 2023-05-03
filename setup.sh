#!/bin/bash

current_dir=`pwd`
mkdir ~/.config
ln -sfn $current_dir/alacritty ~/.config/alacritty
ln -sfn $current_dir/tmux ~/.config/tmux
# use "C-x I" to initialize tmux

git submodule add https://github.com/alacritty/alacritty-theme alacritty/alacritty-theme
git submodule add https://github.com/tmux-plugins/tpm tmux/plugins/tpm
