#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  x-ui Custom Colors Installer (EazyXray)
#  Author: Schmi7zz | Telegram: @Schmi7zz | Channel: @Schmitzws
# ============================================================

SCRIPT_NAME="xui-colors"
STATE_DIR="/etc/x-ui/${SCRIPT_NAME}"
BACKUP_PATH_FILE="${STATE_DIR}/backup_path"

INSTALL_DIR="/usr/local/x-ui"
BIN="${INSTALL_DIR}/x-ui"
SERVICE="x-ui"

WORKDIR="/root/x-ui-colors-build"
REPO_URL_DEFAULT="https://github.com/MHSanaei/3x-ui.git"

usage() {
  cat <<'EOF'
Usage:
  xui-colors.sh install   [--repo <git_url>] [--yes]
  xui-colors.sh uninstall [--yes]
  xui-colors.sh status

Example one-liners:
  curl -fsSL "https://raw.githubusercontent.com/<YOU>/<REPO>/main/xui-colors.sh" | sudo bash -s -- install --yes
  curl -fsSL "https://raw.githubusercontent.com/<YOU>/<REPO>/main/xui-colors.sh" | sudo bash -s -- uninstall --yes
EOF
}

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "ERROR: run as root (use sudo)."
    exit 1
  fi
}

confirm() {
  local prompt="$1"
  if [[ "${ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  read -r -p "${prompt} [y/N] " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

ensure_deps_ubuntu() {
  apt update
  apt install -y git ca-certificates build-essential golang python3
}

service_stop() { systemctl stop "${SERVICE}" || true; }
service_start() { systemctl start "${SERVICE}" || true; }
service_status() { systemctl status "${SERVICE}" --no-pager || true; }

make_backup() {
  mkdir -p "${STATE_DIR}"
  local ts backup
  ts="$(date +%Y%m%d-%H%M%S)"
  backup="${BIN}.bak.${ts}"
  cp -a "${BIN}" "${backup}"
  echo "${backup}" > "${BACKUP_PATH_FILE}"
  echo "Backup created: ${backup}"
}

restore_backup() {
  if [[ ! -f "${BACKUP_PATH_FILE}" ]]; then
    echo "No uninstall backup recorded at ${BACKUP_PATH_FILE}."
    echo "Available backups:"
    ls -1t "${BIN}.bak."* 2>/dev/null | head -n 10 || true
    exit 2
  fi
  local backup
  backup="$(cat "${BACKUP_PATH_FILE}")"
  if [[ ! -f "${backup}" ]]; then
    echo "Recorded backup missing: ${backup}"
    ls -1t "${BIN}.bak."* 2>/dev/null | head -n 10 || true
    exit 2
  fi

  service_stop
  cp -a "${backup}" "${BIN}"
  chmod 755 "${BIN}" || true
  service_start
  echo "Restored: ${backup}"
  service_status
}

patch_source() {
  python3 - <<'PY'
import re, sys

def add_protocol_tag_class(html: str) -> str:
    """
    Add class="protocol-tag" to specific <a-tag> elements showing protocol/network/TLS/Reality.
    This is intentionally regex-based to avoid brittle exact-string matching and escaping issues.
    """
    def add_class_to_open_tag(tag_open: str) -> str:
        if 'class=' in tag_open:
            # If class exists but doesn't include protocol-tag, append it.
            m = re.search(r'class\s*=\s*"([^"]*)"', tag_open)
            if m and 'protocol-tag' not in m.group(1).split():
                return re.sub(r'class\s*=\s*"([^"]*)"', lambda mm: f'class="{mm.group(1)} protocol-tag"', tag_open, count=1)
            m = re.search(r"class\s*=\s*'([^']*)'", tag_open)
            if m and 'protocol-tag' not in m.group(1).split():
                return re.sub(r"class\s*=\s*'([^']*)'", lambda mm: f"class='{mm.group(1)} protocol-tag'", tag_open, count=1)
            return tag_open
        # No class attr; inject one.
        return tag_open.replace("<a-tag", '<a-tag class="protocol-tag"', 1)

    patterns = [
        r"(<a-tag\b[^>]*>)([\s\S]*?dbInbound\.toInbound\(\)\.stream\.network[\s\S]*?</a-tag>)",
        r"(<a-tag\b[^>]*>)([\s\S]*?>\s*TLS\s*</a-tag>)",
        r"(<a-tag\b[^>]*>)([\s\S]*?>\s*Reality\s*</a-tag>)",
        r"(<a-tag\b[^>]*>)([\s\S]*?>\s*tls\s*</a-tag>)",
        r"(<a-tag\b[^>]*>)([\s\S]*?>\s*reality\s*</a-tag>)",
    ]

    for pat in patterns:
        html = re.sub(
            pat,
            lambda m: add_class_to_open_tag(m.group(1)) + m.group(2),
            html,
            flags=re.IGNORECASE,
        )
    return html

for fp in ("web/html/inbounds.html", "web/html/modals/inbound_info_modal.html"):
    try:
        with open(fp, "r", encoding="utf-8") as f:
            c = f.read()
    except FileNotFoundError:
        continue
    with open(fp, "w", encoding="utf-8") as f:
        f.write(add_protocol_tag_class(c))

theme_path = "web/html/component/aThemeSwitch.html"
s = open(theme_path, "r", encoding="utf-8").read()

insert_at = s.find('{{define "component/aThemeSwitch"}}')
if insert_at == -1:
    print("aThemeSwitch: cannot find component/aThemeSwitch", file=sys.stderr)
    sys.exit(2)

if '{{define "component/themeCustomizerTemplate"}}' not in s:
    modal = r'''{{define "component/themeCustomizerTemplate"}}
<template>
  <a-modal :visible="themeCustomizer.visible" title="Custom colors" :footer="null" @cancel="themeCustomizer.close()">
    <a-space direction="vertical" :size="12" :style="{ width: '100%' }">
      <a-space direction="horizontal" align="center">
        <a-switch :checked="themeCustomizer.enabled" @change="themeCustomizer.setEnabled"></a-switch>
        <span>Enable custom colors</span>
      </a-space>

      <a-form layout="vertical">
        <a-form-item label="Primary (accent / links / highlights)">
          <input type="color" v-model="themeCustomizer.colors.primary" style="width: 100%; height: 36px;" />
        </a-form-item>
        <a-form-item label="Background (light)">
          <input type="color" v-model="themeCustomizer.colors.lightBackground" style="width: 100%; height: 36px;" />
        </a-form-item>
        <a-form-item label="Surface (light)">
          <input type="color" v-model="themeCustomizer.colors.lightSurface" style="width: 100%; height: 36px;" />
        </a-form-item>
        <a-form-item label="Table header (light)">
          <input type="color" v-model="themeCustomizer.colors.tableHeaderBg" style="width: 100%; height: 36px;" />
        </a-form-item>
        <a-form-item label="Text (light)">
          <input type="color" v-model="themeCustomizer.colors.lightText" style="width: 100%; height: 36px;" />
        </a-form-item>
        <a-form-item label="Hover background (light)">
          <input type="color" v-model="themeCustomizer.colors.hoverBg" style="width: 100%; height: 36px;" />
        </a-form-item>

        <a-space direction="horizontal" :size="8" class="w-100" style="justify-content: flex-end;">
          <a-button @click="themeCustomizer.reset()">Reset</a-button>
          <a-button type="primary" @click="themeCustomizer.save()">Save</a-button>
        </a-space>
      </a-form>
    </a-space>
  </a-modal>
</template>
{{end}}

'''
    s = s[:insert_at] + modal + s[insert_at:]
else:
    s = re.sub(r'\\s*<a-form-item label="Advanced CSS \\(optional\\)">[\\s\\S]*?</a-form-item>\\s*', "\\n", s, count=1)

# IMPORTANT: keep this marker identical to upstream template text.
# Using Python-style escapes (\\") here has caused SyntaxError on some systems.
marker = "{{define \"component/aThemeSwitch\"}}\n<script>\n"
if marker not in s:
    print("aThemeSwitch: script marker not found", file=sys.stderr)
    sys.exit(3)

def_block = r"function createThemeCustomizer\(\)\s*\{[\s\S]*?\n\s*\}\n"
if re.search(def_block, s):
    s = re.sub(def_block, "", s, count=1)

inject = r'''  function createThemeCustomizer() {
    const STORAGE_ENABLED = 'custom-theme-enabled';
    const STORAGE_COLORS = 'custom-theme-colors';
    const STYLE_ID = 'custom-theme-style';

    const defaultColors = {
      primary: '#008771',
      lightBackground: '#ffffff',
      lightSurface: '#ffffff',
      tableHeaderBg: '#ffffff',
      lightText: '#000000',
      hoverBg: '#e8f4f2',
    };

    function safeParseJson(value, fallback) {
      try {
        if (!value) return fallback;
        const parsed = JSON.parse(value);
        return parsed && typeof parsed === 'object' ? parsed : fallback;
      } catch (e) {
        return fallback;
      }
    }

    function normalizeColor(value) {
      if (typeof value !== 'string') return '';
      const v = value.trim();
      if (!v) return '';
      return /^#[0-9a-fA-F]{6}$/.test(v) ? v : '';
    }

    function upsertStyleTag(cssText) {
      let tag = document.getElementById(STYLE_ID);
      if (!tag) {
        tag = document.createElement('style');
        tag.id = STYLE_ID;
        document.head.appendChild(tag);
      }
      tag.textContent = cssText;
    }

    function removeStyleTag() {
      const tag = document.getElementById(STYLE_ID);
      if (tag && tag.parentNode) tag.parentNode.removeChild(tag);
    }

    function buildCss(colors) {
      colors = colors || {};
      const primary = normalizeColor(colors.primary) || defaultColors.primary;
      const lightBg = normalizeColor(colors.lightBackground) || defaultColors.lightBackground;
      const lightSurface = normalizeColor(colors.lightSurface) || defaultColors.lightSurface;
      const tableHeaderBg = normalizeColor(colors.tableHeaderBg) || defaultColors.tableHeaderBg;
      const lightText = normalizeColor(colors.lightText) || defaultColors.lightText;
      const hoverBg = normalizeColor(colors.hoverBg) || defaultColors.hoverBg;

      return `
:root{--color-primary-100:${primary};}
body.light{background-color:${lightBg} !important;color:${lightText} !important;}
body.light .ant-layout, body.light .ant-layout-content{background-color:${lightBg} !important;color:${lightText} !important;}
body.light .ant-card, body.light .ant-tabs, body.light .ant-table, body.light .ant-collapse-content, body.light .ant-modal-content{background-color:${lightSurface} !important;color:${lightText} !important;}
body.light .ant-table-thead>tr>th, body.light .ant-table-header, body.light .ant-table-title, body.light .ant-table-footer{background-color:${tableHeaderBg} !important;color:${lightText} !important;}
body.light .ant-menu:not(.ant-menu-horizontal) .ant-menu-item-selected{background-color:var(--color-primary-100) !important;background-image:none !important;color:#fff !important;}
body.light .ant-switch-checked{background-color:var(--color-primary-100) !important;}
body.light .ant-tag-green:not(.protocol-tag){border-color:var(--color-primary-100) !important;color:var(--color-primary-100) !important;}
body.light .ant-menu-item:hover, body.light .ant-menu-submenu-title:hover, body.light .ant-table-tbody>tr:hover>td{background-color:${hoverBg} !important;}
body.light .ant-btn-primary{background-color:var(--color-primary-100) !important;border-color:var(--color-primary-100) !important;}
      `.trim();
    }

    const enabled = localStorage.getItem(STORAGE_ENABLED) === 'true';
    const storedColors = safeParseJson(localStorage.getItem(STORAGE_COLORS), {});
    const colors = Object.assign({}, defaultColors, storedColors);

    if (enabled) upsertStyleTag(buildCss(colors));

    const themeCustomizer = {
      visible: false,
      enabled,
      colors,
      open() { themeCustomizer.visible = true; },
      close() { themeCustomizer.visible = false; },
      setEnabled(checked) {
        themeCustomizer.enabled = !!checked;
        localStorage.setItem(STORAGE_ENABLED, themeCustomizer.enabled ? 'true' : 'false');
        if (themeCustomizer.enabled) upsertStyleTag(buildCss(themeCustomizer.colors || defaultColors));
        else removeStyleTag();
      },
      save() {
        localStorage.setItem(STORAGE_COLORS, JSON.stringify(themeCustomizer.colors || defaultColors));
        if (themeCustomizer.enabled) upsertStyleTag(buildCss(themeCustomizer.colors || defaultColors));
        themeCustomizer.visible = false;
      },
      reset() { themeCustomizer.colors = Object.assign({}, defaultColors); }
    };

    return themeCustomizer;
  }

'''
s = s.replace(marker, marker + inject, 1)

if "const themeCustomizer = createThemeCustomizer();" not in s:
    s = s.replace("  const themeSwitcher = createThemeSwitcher();",
                  "  const themeSwitcher = createThemeSwitcher();\n  const themeCustomizer = createThemeCustomizer();", 1)

if "Vue.component('a-theme-customizer'" not in s:
    s = s.replace("</script>",
                  "  Vue.component('a-theme-customizer', {\n"
                  "    template: `{{template \"component/themeCustomizerTemplate\" .}}`,\n"
                  "    data: () => ({ themeCustomizer })\n"
                  "  });\n"
                  "</script>", 1)

open(theme_path, "w", encoding="utf-8").write(s)

side_path = "web/html/component/aSidebar.html"
t = open(side_path, "r", encoding="utf-8").read()

t = t.replace("            <a-theme-switch></a-theme-switch>\n", "")
t = t.replace("            <a-theme-switch></a-theme-switch>\r\n", "")

if "<a-theme-customizer></a-theme-customizer>" not in t:
    t = t.replace("</a-menu>\n        </a-layout-sider>",
                  "</a-menu>\n            <a-theme-customizer></a-theme-customizer>\n        </a-layout-sider>", 1)
    t = t.replace("</a-menu>\n        </a-drawer>",
                  "</a-menu>\n            <a-theme-customizer></a-theme-customizer>\n        </a-drawer>", 1)

theme_submenu = (
    '                <a-sub-menu key="__theme">\n'
    '                    <span slot="title">\n'
    '                        <a-icon type="bulb" :theme="themeSwitcher.isDarkTheme ? \'filled\' : \'outlined\'"></a-icon>\n'
    '                        <span>{{ i18n "menu.theme" }}</span>\n'
    '                    </span>\n'
    '                    <a-menu-item key="__theme_dark"><span>{{ i18n "menu.dark" }}</span><a-switch size="small" :checked="themeSwitcher.isDarkTheme" :style="{ marginLeft: \'8px\' }"></a-switch></a-menu-item>\n'
    '                    <a-menu-item key="__theme_ultra" v-if="themeSwitcher.isDarkTheme"><span>{{ i18n "menu.ultraDark" }}</span><a-checkbox :checked="themeSwitcher.isUltra" :style="{ marginLeft: \'8px\' }"></a-checkbox></a-menu-item>\n'
    '                    <a-menu-item key="__theme_custom"><a-icon type="bg-colors"></a-icon><span style="margin-left:6px">Custom colors</span></a-menu-item>\n'
    '                </a-sub-menu>\n'
)

menu_open = '<a-menu :theme="themeSwitcher.currentTheme" mode="inline" :selected-keys="activeTab"\n                @click="({key}) => openLink(key)">'
parts = t.split(menu_open)
if len(parts) >= 3:
    t = menu_open.join([parts[0], theme_submenu + parts[1], theme_submenu + menu_open.join(parts[2:])])
elif len(parts) == 2:
    t = parts[0] + menu_open + theme_submenu + parts[1]

t = re.sub(r"openLink\(key\)\s*\{[\s\S]*?location\.href\s*=\s*key[\s\S]*?\}",
           """openLink(key) {
                if (String(key).startsWith('__theme_')) {
                    if (key === '__theme_dark') return themeSwitcher.toggleTheme();
                    if (key === '__theme_ultra') return themeSwitcher.toggleUltra();
                    if (key === '__theme_custom') return themeCustomizer.open();
                    return;
                }
                return key.startsWith('http') ?
                    window.open(key) :
                    location.href = key
            }""",
           t, count=1)

if "themeCustomizer" not in t.split("return {", 1)[1].split("}", 1)[0]:
    t = t.replace("return {", "return {\n                themeCustomizer,", 1)

open(side_path, "w", encoding="utf-8").write(t)

print("OK patched all")
PY
}

do_install() {
  local repo_url="$1"
  echo "Author: @Schmi7zz | Channel: @Schmitzws"
  ensure_deps_ubuntu

  rm -rf "${WORKDIR}"
  mkdir -p "${WORKDIR}"
  cd "${WORKDIR}"
  git clone "${repo_url}" src
  cd src

  patch_source

  echo "Building x-ui..."
  go build -ldflags "-w -s" -o x-ui-custom main.go

  echo "Backing up current binary..."
  make_backup

  echo "Installing new binary and restarting ${SERVICE}..."
  service_stop
  install -m 0755 ./x-ui-custom "${BIN}"
  service_start
  service_status

  echo ""
  echo "Done. Sidebar -> Theme -> Custom colors."
  echo "Author: @Schmi7zz | Channel: @Schmitzws"
}

do_status() {
  echo "Service: ${SERVICE}"
  service_status
  echo ""
  echo "Latest backups:"
  ls -1t "${BIN}.bak."* 2>/dev/null | head -n 5 || true
  echo ""
  if [[ -f "${BACKUP_PATH_FILE}" ]]; then
    echo "Uninstall backup recorded:"
    cat "${BACKUP_PATH_FILE}"
  fi
}

main() {
  need_root
  local cmd="${1:-install}"
  shift || true

  local repo_url="${REPO_URL_DEFAULT}"
  ASSUME_YES=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo) repo_url="$2"; shift 2;;
      --yes) ASSUME_YES=1; shift;;
      -h|--help) usage; exit 0;;
      *) echo "Unknown arg: $1"; usage; exit 1;;
    esac
  done

  case "${cmd}" in
    install)
      confirm "This will rebuild and replace ${BIN}. Continue?" || exit 1
      do_install "${repo_url}"
      ;;
    uninstall)
      confirm "This will restore the saved backup. Continue?" || exit 1
      restore_backup
      ;;
    status)
      do_status
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
