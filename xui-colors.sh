#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  x-ui Custom Colors Installer
#  Author: Schmi7zz  | Telegram: @Schmi7zz | Channel: @Schmitzws
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

Notes:
  - Install rebuilds x-ui from source and patches the web UI.
  - Uninstall restores the exact backup created by install (if available).
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
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  local backup="${BIN}.bak.${ts}"
  cp -a "${BIN}" "${backup}"
  echo "${backup}" > "${BACKUP_PATH_FILE}"
  echo "Backup created: ${backup}"
}

restore_backup() {
  if [[ ! -f "${BACKUP_PATH_FILE}" ]]; then
    echo "No backup file found at ${BACKUP_PATH_FILE}."
    echo "Available backups:"
    ls -1t "${BIN}.bak."* 2>/dev/null | head -n 10 || true
    exit 2
  fi

  local backup
  backup="$(cat "${BACKUP_PATH_FILE}")"
  if [[ ! -f "${backup}" ]]; then
    echo "Backup path recorded but file missing: ${backup}"
    echo "Available backups:"
    ls -1t "${BIN}.bak."* 2>/dev/null | head -n 10 || true
    exit 2
  fi

  service_stop
  cp -a "${backup}" "${BIN}"
  chmod 755 "${BIN}" || true
  service_start
  echo "Restored backup: ${backup}"
  service_status
}

patch_source() {
  python3 - <<'PY'
import re, sys

# ---------- 1) Protect protocol tags (tcp/ws/...) ----------
def add_protocol_tag_class(html: str) -> str:
    repls = [
        ('<a-tag :style="{ margin: \\'0\\' }" color="green">[[\\n                          dbInbound.toInbound().stream.network ]]</a-tag>',
         '<a-tag class="protocol-tag" :style="{ margin: \\'0\\' }" color="green">[[\\n                          dbInbound.toInbound().stream.network ]]</a-tag>'),
        ('<a-tag :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isTls"\\n                          color="blue">TLS</a-tag>',
         '<a-tag class="protocol-tag" :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isTls"\\n                          color="blue">TLS</a-tag>'),
        ('<a-tag :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isReality"\\n                          color="blue">Reality</a-tag>',
         '<a-tag class="protocol-tag" :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isReality"\\n                          color="blue">Reality</a-tag>'),
        ('<a-tag :style="{ margin: \\'0\\' }" color="blue">[[\\n                                    dbInbound.toInbound().stream.network',
         '<a-tag class="protocol-tag" :style="{ margin: \\'0\\' }" color="blue">[[\\n                                    dbInbound.toInbound().stream.network'),
        ('<a-tag :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isTls"\\n                                    color="green">tls</a-tag>',
         '<a-tag class="protocol-tag" :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isTls"\\n                                    color="green">tls</a-tag>'),
        ('<a-tag :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isReality"\\n                                    color="green">reality</a-tag>',
         '<a-tag class="protocol-tag" :style="{ margin: \\'0\\' }" v-if="dbInbound.toInbound().stream.isReality"\\n                                    color="green">reality</a-tag>'),
    ]
    for a,b in repls:
        html = html.replace(a,b)
    return html

for fp in ["web/html/inbounds.html", "web/html/modals/inbound_info_modal.html"]:
    try:
        c = open(fp, "r", encoding="utf-8").read()
    except FileNotFoundError:
        continue
    open(fp, "w", encoding="utf-8").write(add_protocol_tag_class(c))

# ---------- 2) Patch aThemeSwitch.html (NO advanced CSS, add table header bg picker) ----------
theme_path = "web/html/component/aThemeSwitch.html"
s = open(theme_path, "r", encoding="utf-8").read()

insert_at = s.find('{{define "component/aThemeSwitch"}}')
if insert_at == -1:
    print("aThemeSwitch: cannot find component/aThemeSwitch", file=sys.stderr); sys.exit(2)

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

marker = "{{define \\"component/aThemeSwitch\\"}}\\n<script>\\n"
if marker not in s:
    print("aThemeSwitch: script marker not found", file=sys.stderr); sys.exit(3)

def_block = r"function createThemeCustomizer\\(\\)\\s*\\{[\\s\\S]*?\\n\\s*\\}\\n"
m = re.search(def_block, s)
if not m:
    s = s.replace(marker, marker + "\\n", 1)
else:
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

body.light, body.light .ant-card, body.light .ant-card-body, body.light .ant-tabs, body.light .ant-table,
body.light .ant-collapse, body.light .ant-collapse-content, body.light .ant-modal-content, body.light .ant-modal-header,
body.light .ant-statistic-title, body.light .ant-statistic-content, body.light .ant-statistic-content-value,
body.light .ant-alert-message, body.light .ant-alert-description{color:${lightText} !important;}

body.light .ant-card, body.light .ant-tabs, body.light .ant-table, body.light .ant-collapse-content,
body.light .ant-drawer-content, body.light .ant-modal-content{background-color:${lightSurface} !important;}

body.light .ant-table-thead>tr>th,
body.light .ant-table-header,
body.light .ant-table-title,
body.light .ant-table-footer{
  background-color:${tableHeaderBg} !important;
  color:${lightText} !important;
}

body.light .ant-layout-sider, body.light .ant-layout-sider-children, body.light .ant-menu{background-color:${lightBg} !important;}
body.light .ant-layout-sider-trigger{background-color:${lightBg} !important;color:${lightText} !important;border-top:1px solid rgba(0,0,0,0.08) !important;}

body.light .ant-menu-item, body.light .ant-menu-submenu-title{color:${lightText} !important;}

body.light .ant-menu:not(.ant-menu-horizontal) .ant-menu-item-selected{
  background-color:var(--color-primary-100) !important;
  background-image:none !important;
  color:#fff !important;
  border-radius:.5rem !important;
}
body.light .ant-menu-item-selected a, body.light .ant-menu-item-selected span{color:#fff !important;}

body.light .ant-switch-checked{background-color:var(--color-primary-100) !important;}
body.light .ant-checkbox-checked .ant-checkbox-inner{background-color:var(--color-primary-100) !important;border-color:var(--color-primary-100) !important;}

body.light .ant-tag-green:not(.protocol-tag){
  background-color:rgba(0,0,0,0.03) !important;
  border-color:var(--color-primary-100) !important;
  color:var(--color-primary-100) !important;
}

body.light .ant-menu-item:hover,
body.light .ant-menu-submenu-title:hover,
body.light .ant-table-tbody>tr:hover>td,
body.light .ant-dropdown-menu-item:hover,
body.light .ant-select-dropdown-menu-item:hover{
  background-color:${hoverBg} !important;
}

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

# ---------- Sidebar: Theme menu added in both desktop + drawer ----------
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
PY

go build -ldflags "-w -s" -o x-ui-custom main.go

systemctl stop "$SERVICE"
cp -a "$BIN" "${BIN}.bak.$(date +%Y%m%d-%H%M%S)"
install -m 0755 ./x-ui-custom "$BIN"
systemctl start "$SERVICE"
systemctl status "$SERVICE" --no-pager
BASH
EOF

# Make the rebuild script itself executable and run it
chmod +x /root/rebuild-xui-custom-colors-v18.sh
sudo bash /root/rebuild-xui-custom-colors-v18.sh

echo ""
echo "Done. Theme -> Custom colors is now available."
echo "Author: @Schmi7zz | Channel: @Schmitzws"
EOF

chmod +x "$TARGET"

# Run the installer (creates & runs the rebuild script)
bash "$TARGET"
echo "Installer finished."
