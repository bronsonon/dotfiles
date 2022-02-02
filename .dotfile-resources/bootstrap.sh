#!/usr/bin/env bash

# USAGE:
# `./bootstrap.sh` will install or update home dotfiles.
# `./bootstrap.sh --provision` will install software.
# `./bootstrap.sh --revert` will revert previous install or update. This can be done several times to go back in time until there are no backups available.

GIT_REMOTE="git@github.com:mckinley/dotfiles.git"
GIT_DIR="$HOME/.dotfiles"
BACKUPS_DIR="$HOME/.dotfile-backups"
RESOURCES_DIR="$HOME/.dotfile-resources"
TMP_DIR="$(dirname "${BASH_SOURCE}")/tmp"

provision() {
  #  Install Xcode Command Line Tools
  #  https://developer.apple.com/download/more/?=command%20line%20tools
  xcode-select --install

  #  https://brew.sh/
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

  #  https://asdf-vm.com/#/core-manage-asdf
  #  Dependencies
  brew install coreutils curl git
  #  Install
  brew install asdf

  #  https://github.com/asdf-vm/asdf-ruby#install
  #  Dependencies (ruby-build: https://github.com/rbenv/ruby-build/wiki#macos)
  brew install openssl readline
  asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git
  asdf install ruby 2.7.2
  asdf global ruby 2.7.2

  #  https://github.com/asdf-vm/asdf-nodejs#install
  #  Dependencies (https://github.com/asdf-vm/asdf-nodejs#macos)
  brew install coreutils gpg
  asdf plugin-add nodejs https://github.com/asdf-vm/asdf-nodejs.git
  #  Import the Node.js release team's OpenPGP keys to main keyring
  bash -c '${ASDF_DATA_DIR:=$HOME/.asdf}/plugins/nodejs/bin/import-release-team-keyring'
  asdf install nodejs 14.17.6
  asdf global nodejs 14.17.6

  #  https://github.com/danhper/asdf-python
  #  Dependencies (pyenv: https://github.com/pyenv/pyenv/wiki#suggested-build-environment)
  brew install openssl readline sqlite3 xz zlib
  asdf plugin-add python
  asdf install python 3.9.7
  asdf global python 3.9.7

  #  https://github.com/kennyp/asdf-golang
  #  Dependencies (https://github.com/kennyp/asdf-golang#macos)
  brew install coreutils
  asdf plugin-add golang https://github.com/kennyp/asdf-golang.git
  asdf install golang 1.17
  asdf global golang 1.17

  #  https://formulae.brew.sh/formula/zsh
  brew install zsh

  chsh -s $(which zsh)

  #  https://github.com/ohmyzsh/ohmyzsh#unattended-install
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc

  # Zsh complains about homebrew's directory permissions
  # drwxrwxr-x  7 bronson  admin  224 Oct  3 15:07 /usr/local/share/zsh
  # drwxrwxr-x  4 bronson  admin  128 Oct  3 15:06 /usr/local/share/zsh/site-functions
  # compaudit | xargs chmod g-w,o-w

  #  https://github.com/wting/autojump#os-x
  brew install autojump

  #  https://direnv.net/docs/installation.html
  brew install direnv

  #  https://git-scm.com/
  brew install git

  # https://cli.github.com/
  brew install gh

  #  https://classic.yarnpkg.com/en/docs/install#mac-stable
  brew install yarn

  #  https://devcenter.heroku.com/articles/heroku-cli
  brew tap heroku/brew && brew install heroku

  #  https://wiki.postgresql.org/wiki/Homebrew
  brew install postgresql && brew services start postgresql

  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
}

dotfiles() {
  git --git-dir="$GIT_DIR" --work-tree="$HOME" "$@"
}

install() {
  BACKUP_DIR="$BACKUPS_DIR/$(date +%Y-%m-%d-%s)"

  echo "Installing dotfiles..."

  echo "- Cloning repo to tmp dir with separate git dir '$GIT_DIR'"
  rm -rf "$GIT_DIR"
  mkdir -p "$TMP_DIR"
  git clone --separate-git-dir="$GIT_DIR" "$GIT_REMOTE" "$TMP_DIR"

  echo "- Syncing home with tmp repo and creating backup '$BACKUP_DIR'"
  rsync --backup --recursive --checksum --verbose \
    --backup-dir="$BACKUP_DIR" \
    --exclude={.DS_Store,.git,.idea} \
    "$TMP_DIR/" "$HOME/"

  echo "- Removing tmp repo"
  rm -rf "$TMP_DIR"

  echo "- Configuring home repo"
  dotfiles config --local status.showUntrackedFiles no

  echo "- Reset default shell"
  exec zsh -l

  echo "Install complete."
}

revert() {
  LAST_BACKUP="$BACKUPS_DIR/$(ls -tr "$BACKUPS_DIR" | tail -n 1)"

  if [ -z "$(ls "$BACKUPS_DIR")" ]; then
    echo "No backups where found at $BACKUPS_DIR."
    return
  fi

  echo "Reverting dotfiles..."
  echo "- Last backup: $LAST_BACKUP"

  rsync --recursive --checksum --verbose \
    --exclude ".DS_Store" \
    "$LAST_BACKUP/" "$HOME/"
  rm -rf "$LAST_BACKUP"

  echo "- Reset default shell"
  exec zsh -l

  echo "Revert complete."
}

if [[ "$1" == "--revert" ]]; then
  revert
elif [[ "$1" == "--provision" ]]; then
  provision
else
  install
fi
