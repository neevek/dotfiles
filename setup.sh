#!/bin/bash

# git submodule add https://github.com/alacritty/alacritty-theme alacritty/alacritty-theme
# git submodule add https://github.com/tmux-plugins/tpm tmux/plugins/tpm

which tmux > /dev/null 2>&1
if [[ "$?" != "0" ]]; then
 echo "Install tmux first"
 exit 1
fi

which zsh > /dev/null 2>&1 || sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

if [[ `uname -s` = "Linux" ]]; then
  perl -pi -e 's/set-option -g prefix C-x/set-option -g prefix C-z/' ./tmux/tmux.conf
fi

current_dir=`pwd`
mkdir -p ~/.config

ln -sfn $current_dir/zsh/neevek.zsh-theme ~/.oh-my-zsh/themes/neevek.zsh-theme
ln -sfn $current_dir/git/gitconfig ~/.gitconfig
ln -sfn $current_dir/alacritty ~/.config/alacritty
ln -sfn $current_dir/tmux ~/.config/tmux

tmux run-shell ./tmux/plugins/tpm/bin/install_plugins && tmux source ./tmux/tmux.conf
# or we can manually do the above using "C-x I" to initialize tmux

echo "Pulling submodules..."
git submodule update --init --recursive
git submodule foreach --recursive git submodule update --remote --merge
git submodule update --recursive --checkout

sed -i -e 's/ZSH_THEME=".*"/ZSH_THEME="neevek"/' ~/.zshrc

echo -e "\nDone! Remember to run: source ~/.zshrc"
