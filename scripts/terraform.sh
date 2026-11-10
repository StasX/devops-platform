#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_cloud=aws
if [[ "${1:-}" == aws || "${1:-}" == gcp || "${1:-}" == azure || "${1:-}" == vsphere ]]; then
  target_cloud="$1"
  shift
fi
env_path="$script_dir/../.env"
if [[ ! -f "$env_path" ]]; then
  echo 'Missing root .env. Copy .env.example to .env and configure it first.' >&2
  exit 1
fi

# Parse literal KEY=VALUE lines; never source or eval the file.
line_number=0
while IFS= read -r line || [[ -n "$line" ]]; do
  line_number=$((line_number + 1))
  line="${line%$'\r'}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ ! "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    echo "Invalid .env assignment on line $line_number. Expected KEY=VALUE." >&2
    exit 1
  fi
  name="${BASH_REMATCH[1]}"
  value="${BASH_REMATCH[2]}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ ${#value} -ge 2 && ( "$value" == \"*\" || "$value" == \'*\' ) ]]; then
    value="${value:1:${#value}-2}"
  fi
  export "$name=$value"
done < "$env_path"

exec terraform "-chdir=$script_dir/../terraform/$target_cloud" "$@"
