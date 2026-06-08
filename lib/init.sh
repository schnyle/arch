: "${host:=}"
: "${repo_root:=}"

for f in "$repo_root"/lib/*.sh; do
  [[ "$(basename "$f")" == "init.sh" ]] && continue
  source "$f"
done

source "$repo_root/hosts/$host.sh"
