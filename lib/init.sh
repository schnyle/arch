: "${host:=}"
: "${repo_root:=}"

for f in "$repo_root"/lib/*.sh; do
  [[ "$(basename "$f")" == "init.sh" ]] && continue
  source "$f"
done

host_dir="$repo_root/hosts/$host"
source "$host_dir/vars.sh"
