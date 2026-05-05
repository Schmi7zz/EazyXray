#!/usr/bin/env bash
set -euo pipefail

# Thin wrapper so GitHub raw URL can be:
#   https://raw.githubusercontent.com/<YOU>/<REPO>/main/xui-colors.sh

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/xui-colors-installer/xui-colors.sh" "$@"

