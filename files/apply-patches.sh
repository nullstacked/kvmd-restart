#!/bin/bash
set -e

SHARE_DIR="/usr/share/kvmd-restart"
LOG_PREFIX="kvmd-restart"
WEB_DIR="/usr/share/kvmd/web"

log() { echo "[$LOG_PREFIX] $*"; }
warn() { echo "[$LOG_PREFIX] WARNING: $*" >&2; }

# Copy CSS. Restart is the destructive button, so on the client units - where
# the right-edge ladder runs all the way down to recap at 478px - it sits last,
# at 540px, behind a deliberate 32px gap rather than wedged between Listen and
# Record where it used to be (<=1.0.4). Support units have no listen/ask/recap
# buttons, so moving it there would just leave it floating alone below a hole;
# they keep 310px. /etc/kvmd/listen.conf is the marker for "client unit with
# the full ladder" - bin/provision-pikvm writes it, same as for kvmd-listen.
dest="$WEB_DIR/share/css/kvm/restart.css"
mkdir -p "$(dirname "$dest")"
staged=$(mktemp)
if [ -f /etc/kvmd/listen.conf ]; then
    sed 's/--cs-restart-top: 310px;/--cs-restart-top: 540px;/' \
        "$SHARE_DIR/restart.css" > "$staged"
    if ! grep -q -- '--cs-restart-top: 540px;' "$staged"; then
        warn "FAILED: could not set the client-unit restart offset in restart.css"
        rm -f "$staged"; exit 1
    fi
else
    cp "$SHARE_DIR/restart.css" "$staged"
fi
if [ -f "$dest" ] && cmp -s "$staged" "$dest"; then
    log "SKIPPED (unchanged): restart.css"
else
    cp "$staged" "$dest"
    log "PATCHED: restart.css"
fi
rm -f "$staged"

# Patch index.html + session.js via Python
python3 <<'PYEOF'
import os, sys

WEB_DIR = "/usr/share/kvmd/web"

# ============================================================
# Patch index.html — add CSS link + floating button
# ============================================================
path = os.path.join(WEB_DIR, "kvm", "index.html")
if os.path.exists(path):
    content = open(path).read()
    changed = False

    if "restart.css" not in content:
        last_css = content.rfind('<link rel="stylesheet"')
        if last_css >= 0:
            eol = content.find("\n", last_css)
            if eol >= 0:
                link = '\n\t\t<link rel="stylesheet" href="../share/css/kvm/restart.css">'
                content = content[:eol] + link + content[eol:]
                changed = True

    if 'id="kvm-restart-btn"' not in content:
        body_end = content.rfind("</body>")
        if body_end >= 0:
            btn = ('\t\t<button id="kvm-restart-btn" class="kvm-restart-btn" '
                   'title="Restart PiKVM OS">'
                   '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
                   '<path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/>'
                   '</svg></button>\n')
            content = content[:body_end] + btn + content[body_end:]
            changed = True

    if changed:
        open(path, "w").write(content)
        print("[kvmd-restart] PATCHED: index.html")
    else:
        print("[kvmd-restart] SKIPPED (already applied): index.html")
else:
    print("[kvmd-restart] FAILED: index.html not found"); sys.exit(1)

# ============================================================
# Patch session.js — wire up button click to GPIO pulse API
# ============================================================
path = os.path.join(WEB_DIR, "share", "js", "kvm", "session.js")
if os.path.exists(path):
    content = open(path).read()

    if "__restartBtnInit" in content:
        print("[kvmd-restart] SKIPPED (already applied): session.js")
    else:
        func_code = (
            '\n\tvar __restartBtnInit = function() {\n'
            '\t\tlet btn = document.getElementById("kvm-restart-btn");\n'
            '\t\tif (!btn || btn.dataset.initialized) return;\n'
            '\t\tbtn.dataset.initialized = "1";\n'
            '\t\tbtn.addEventListener("mousedown", function(e) { e.preventDefault(); });\n'
            '\t\tbtn.addEventListener("click", function(e) {\n'
            '\t\t\te.preventDefault();\n'
            '\t\t\tif (btn.disabled) return;\n'
            '\t\t\twm.confirm("Restart the PiKVM OS?<br><small>The KVM will be offline for ~30 seconds.</small>").then(function(ok) {\n'
            '\t\t\t\tif (!ok) return;\n'
            '\t\t\t\tbtn.disabled = true;\n'
            '\t\t\t\ttools.httpPost("api/gpio/pulse", {"channel": "kvmd_restart_btn", "wait": 0}, function(http) {\n'
            '\t\t\t\t\tif (http.status !== 200) {\n'
            '\t\t\t\t\t\tbtn.disabled = false;\n'
            '\t\t\t\t\t\twm.error("Restart failed", http.responseText || http.statusText);\n'
            '\t\t\t\t\t}\n'
            '\t\t\t\t\t// 200: PiKVM is rebooting — button stays disabled\n'
            '\t\t\t\t});\n'
            '\t\t\t});\n'
            '\t\t});\n'
            '\t};\n'
            '\tdocument.addEventListener("DOMContentLoaded", __restartBtnInit);\n'
            '\tif (document.readyState !== "loading") __restartBtnInit();\n\n'
        )
        target = '\tvar __wsJsonHandler = function(ev_type, ev) {'
        if target in content:
            content = content.replace(target, func_code + target, 1)
            open(path, "w").write(content)
            print("[kvmd-restart] PATCHED: session.js")
        else:
            print("[kvmd-restart] FAILED: session.js anchor not found"); sys.exit(1)
else:
    print("[kvmd-restart] FAILED: session.js not found"); sys.exit(1)
PYEOF

log "Done"
