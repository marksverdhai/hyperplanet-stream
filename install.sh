#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${HYPERPLANET_BIN_DIR:-${HOME}/.local/bin}"
config_dir="${HYPERPLANET_CONFIG_DIR:-${XDG_CONFIG_HOME:-${HOME}/.config}/hyperplanet-stream}"
data_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/hyperplanet-stream"
venv="${data_dir}/venv"

for command in ffmpeg ffprobe git jq python3 shuf tmux; do
    command -v "$command" >/dev/null || {
        echo "missing prerequisite: $command" >&2
        exit 1
    }
done

umask 077
mkdir -p "$bin_dir" "$config_dir" "$data_dir/shaders"
while IFS= read -r -d '' executable; do
    install -m 0755 "$executable" "$bin_dir"/
done < <(find "$repo_dir/bin" -maxdepth 1 -type f -print0)
install -m 0644 "$repo_dir"/shaders/*.wgsl "$data_dir/shaders"/

python3 -m venv "$venv"
"$venv/bin/pip" install --disable-pip-version-check -r "$repo_dir/requirements.txt"

install_if_absent() {
    local source="$1"
    local target="$2"
    if [[ ! -e "$target" ]]; then
        install -m 0600 "$source" "$target"
    fi
}

install_if_absent "$repo_dir/config/secrets.env.example" "$config_dir/secrets.env"
install_if_absent "$repo_dir/config/chat-listener.example.json" "$config_dir/chat-listener.json"
install_if_absent "$repo_dir/config/stream-watchdog.example.json" "$config_dir/stream-watchdog.json"

printf 'Installed Hyperplanet Stream. Configure %s before starting.\n' "$config_dir"
