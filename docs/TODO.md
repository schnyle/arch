# TODO

## atlas

- `atlas status` reports "In sync" when Atlas is unreachable
- rename "snapshots" to "backups". tedious and unnecessary but preferred nomenclature

## bugs

- `curl -fsSL https://raw.github..... | bash` hits infinite loop. user interaction might just not work for this method.

## new feature

- runtime preflight `validate_modules_exist`: before the converge loop, scan every module a host references and `die` (collect-then-die, listing all) if any module dir is missing — fail loud instead of the silent `[[ ! -f … ]] && continue` skip that installs a passwordless/bootloader-less system. Runtime complement to the commit-time linter above; mirror `validate_required_vars`' signature so both get the same edit at flatten time.
- extract a `render_template` helper (mktemp + sed + ensure_file_content + rm) — see `modules/fail2ban/module.sh`
- explore hoisting user prompting to the front: a `pre_install()` collection pass (mirrors the existing package-aggregation pre-pass) so interactive modules ask everything up front and the convergence loop stays non-interactive/unattended/testable. Open questions: avoid shell globals (subshell isolation loses them) by storing answers as system-state (e.g. disk label) or a state file. Only worth it once >1 interactive module exists — today the lone case (snapshot device) is handled by guard+order or out-of-band labeling.
- add validate required vars to linting
- explore modules declaring preconditions (yay requires user is created)
- update modules to check any preconditions (modules requiring running commands as user should first check that the user exists)
- investigate whether `ensure_service_enabled` should also start the service, useful for `run-module.sh`

## refactor

- add `ensure_dotdir` analogue to `ensure_dotfile` that mirrors a whole directory into `~/.dotfiles/<module>/` — needed once any module symlinks a directory (e.g. neovim's `nvim/`) rather than individual files, since the current `ensure_dotfile` staging copy is skipped when calling `ensure_symlink` directly

- `run/converge.sh` chowns all of `$repo_root` (`/arch-install`) to `system_user` so symlinked dotfiles (`ensure_dotfile`) are editable without sudo — but this leaves a non-root-owned directory sitting directly under `/`, which breaks the convention that only `/home` (and transient dirs like `/run/media/$USER`) hold user-owned paths, and root owns everything else at that level. Proper fix: relocate the repo under `/home/$system_user/...` once the user module has run (it can't live there from the start — during the live-ISO bootstrap phase, `$system_user` doesn't exist yet, so `repo_root` needs a location outside `/home` to begin with). Relocating is a real `cp -a`+`rm -rf`, not a rename, if `/home` is a separate mount/subvolume, and `repo_root` would need to stop being hardcoded (`install.sh`'s `/arch-install`) so callers resolve wherever the repo currently lives.
- dedupe `storage_dirs`/`home_dirs` list between `home-dirs` and `atlas-storage-dirs` modules (currently the same set is hardcoded in both)
- consider making `constants` file for things like `time_zone` used in multiple hosts
- refactor `ufw` to take a `firewall_ports` array per-module (mirroring the `pacman_packages` aggregation in `lib/packages.sh`/`get_pacman_packages`) instead of hardcoding `forgejo_ssh_port`/`forgejo_http_port` directly in the ufw module — deferred since ufw is only used on atlas today; revisit once a second host needs ufw, to keep module isolation intact
- forgejo module pins the `forgejo` user/group UID/GID, but package-created paths (tmpfiles.d dirs like `/var/log/forgejo`, `/etc/forgejo`) retain stale ownership from the original dynamic UID and need individual `ensure_file_ownership` fixes as they're discovered (found `/etc/forgejo` and `/var/log/forgejo` so far). Consider re-running `systemd-tmpfiles --create` for forgejo's rules after the pin instead of whack-a-moling each path

## debt

**nerd fonts (neovim)**: add `ttf-jetbrains-mono-nerd` for nerd fonts, and add below to alacritty
```
[font]
  normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
  bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
  italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
```
design question: should these both be in alarcitty? its for neovim...
