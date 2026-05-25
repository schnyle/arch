# configuration
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log_file="/home/kyle/repos/arch/test/log"

source "$repo_root/lib/common.sh"

init_logging "$log_file"
log "hello"
