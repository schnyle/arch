: "${system_user:=}"

pacman_packages=(
  neovim
  npm
  ripgrep
)

configure() {
  ensure_dotfile "$(script_dir)/init.lua" "/home/$system_user/.config/nvim/init.lua"
}
