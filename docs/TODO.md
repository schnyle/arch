# TODO

- runtime preflight `validate_modules_exist`: before the converge loop, scan every module a host references and `die` (collect-then-die, listing all) if any module dir is missing — fail loud instead of the silent `[[ ! -f … ]] && continue` skip that installs a passwordless/bootloader-less system. Runtime complement to the commit-time linter above; mirror `validate_required_vars`' signature so both get the same edit at flatten time.
- dedupe `storage_dirs`/`home_dirs` list between `home-dirs` and `atlas-storage-dirs` modules (currently the same set is hardcoded in both)
- extract a `render_template` helper (mktemp + sed + ensure_file_content + rm) — currently duplicated in `modules/post-install/fail2ban/module.sh` and `modules/post-install/atlas-snapshot/module.sh`
- explore hoisting user prompting to the front: a `pre_install()` collection pass (mirrors the existing package-aggregation pre-pass) so interactive modules ask everything up front and the convergence loop stays non-interactive/unattended/testable. Open questions: avoid shell globals (subshell isolation loses them) by storing answers as system-state (e.g. disk label) or a state file. Only worth it once >1 interactive module exists — today the lone case (snapshot device) is handled by guard+order or out-of-band labeling.
- add validate required vars to linting
- explore modules declaring preconditions (yay requires user is created)
- update modules to check any preconditions (modules requiring running commands as user should first check that the user exists)
- bug: `curl -fsSL https://raw.github..... | bash` hits infinite loop. user interaction might just not work for this method.

## atlas

- `atlas status` reports "In sync" when Atlas is unreachable
