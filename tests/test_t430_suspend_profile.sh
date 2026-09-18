#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
kernel_config="$repo_root/config/linux-x230-maximized.config"
board_config="$repo_root/boards/EOL_t430-maximized/EOL_t430-maximized.config"

value_is() {
    local key="$1"
    local expected="$2"
    grep -Eq "^CONFIG_${key}=${expected}$" "$kernel_config"
}

value_is PM y || { echo "CONFIG_PM must be enabled" >&2; exit 1; }
value_is SUSPEND y || { echo "CONFIG_SUSPEND must be enabled" >&2; exit 1; }

if grep -Eq '^CONFIG_HIBERNATION=y$' "$kernel_config"; then
    echo "CONFIG_HIBERNATION must remain disabled in the first suspend profile" >&2
    exit 1
fi

grep -Eq '^CONFIG_LINUX_CONFIG=config/linux-x230-maximized.config$' "$board_config"
grep -Eq '^CONFIG_TPMTOTP=y$' "$board_config"
grep -Eq '^CONFIG_HOTPKEY=n$' "$board_config"

echo "T430 suspend profile configuration checks passed."
