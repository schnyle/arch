# shellcheck disable=SC2034

time_zone="/usr/share/zoneinfo/America/Denver"
system_user="kyle"
git_name="Kyle"
email="Kyle.Schneider@charter.com"

post_install_modules=(
  home-dirs
  ohmyzsh
  git
  zsh
  dotfiles
  # ssh-key
  i3
  yay
)

pacman_packages=(
  adobe-source-code-pro-fonts
  alacritty
  diffutils
  firefox
  inetutils
  less
  man-db
  neovim
  npm
  openssh
  qutebrowser
  rsync
  tmux
  tree
  vi
  vim
  xorg-server
  xorg-xinit
  xorg-xset
  xorg-xrandr
  unzip
  wget
  xclip
)
