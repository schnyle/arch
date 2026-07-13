# shellcheck disable=SC2034

time_zone="/usr/share/zoneinfo/America/Denver"
system_user="kyle"
git_name="Kyle"
email="Kyle.Schneider@charter.com"

modules=(
  home-dirs
  alacritty
  ohmyzsh
  git
  gtk
  zsh
  ssh-key
  i3
  yay
  qutebrowser
  tmux
  xorg
  arandr
)

pacman_packages=(
  diffutils
  firefox
  inetutils
  less
  man-db
  neovim
  npm
  openssh
  rsync
  tmux
  tree
  vim
  # xorg-server
  # xorg-xinit
  # xorg-xset
  # xorg-xrandr
  unzip
  wget
  xclip

  dmenu
  tigervnc
  go
  xorg-xrandr
)
