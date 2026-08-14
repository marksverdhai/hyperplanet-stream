#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
while IFS= read -r -d '' script; do
    if head -n 1 "$script" | grep -q 'bash'; then
        bash -n "$script"
    fi
done < <(find "$root/bin" -maxdepth 1 -type f -print0)
bash -n "$root/install.sh"
jq -e '.schemaVersion == 1' "$root"/config/*.json >/dev/null
