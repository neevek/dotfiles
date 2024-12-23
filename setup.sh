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
ln -sfn $current_dir/lvim ~/.config/lvim
# use "C-x I" to initialize tmux

echo "Pulling submodules..."
git submodule update --init alacritty/alacritty-theme
git submodule update --remote --merge alacritty/alacritty-theme
git submodule update --init tmux/plugins/tpm
git submodule update --remote --merge tmux/plugins/tpm

echo "Update zsh theme to 'neevek' in ~/.zshrc, and source it"
echo "Done!"
