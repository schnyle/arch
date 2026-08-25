: "${system_user:=}"

pacman_packages=(
  neovim
  npm
  ripgrep
)

configure() {
  ensure_symlink -u "$system_user" "$(script_dir)/nvim" "/home/$system_user/.config/nvim"
}
