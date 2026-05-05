#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  x-ui Custom Colors Installer (stdin-safe)
#  Author: Schmi7zz | Telegram: @Schmi7zz | Channel: @Schmitzws
# ============================================================
#
# NOTE:
# This script is designed to be run via:
#   curl -fsSL "https://raw.githubusercontent.com/Schmi7zz/EazyXray/main/xui-colors.sh" | sudo bash -s -- install --yes
#
# It does NOT rely on BASH_SOURCE or local files.

URL_INSTALLER="https://raw.githubusercontent.com/Schmi7zz/EazyXray/main/xui-colors-installer/xui-colors.sh"

curl -fsSL "${URL_INSTALLER}" | bash -s -- "$@"

