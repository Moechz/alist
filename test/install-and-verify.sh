#!/bin/bash
# ============================================================================
# On-device end-to-end verification for the AList TOS 7 deb package.
#
# Must run as the TOS administrator (uid 0). It installs the package, exercises
# the platform route through the TOS web server, verifies the review-relevant
# behaviour (non-root service, loopback-only listener, privacy page, WebDAV,
# login, P1 identity, upgrade keeps data, uninstall leaves nothing behind) and
# finally reinstalls the app with the --keep flag.
#
# Usage: bash test/install-and-verify.sh [path/to/alist_x86_64.deb] [--keep]
#        (default package: out/alist_x86_64.deb)
# ============================================================================
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${1:-$HERE/out/alist_x86_64.deb}"
KEEP=0; [ "${2:-}" = "--keep" ] && KEEP=1
APP_ID=alist
APP_PORT=15244
DATA_DIR=/var/lib/$APP_ID
APP_DIR=/usr/local/$APP_ID
MAINT_LOG=/var/log/$APP_ID-maint.log

# TOS web server: 8181 redirects to TLS 5443; prefer TLS, fall back to plain.
WEB="https://127.0.0.1:5443"
CURLK="-k"
if ! curl $CURLK -s -o /dev/null -m 4 "$WEB/" 2>/dev/null; then
  WEB="http://127.0.0.1:8181"; CURLK=""
fi

PASS=0; FAIL=0
ok()   { echo "  [ OK ] $*"; PASS=$((PASS+1)); }
bad()  { echo "  [FAIL] $*"; FAIL=$((FAIL+1)); }
note() { echo "  [info] $*"; }

[ "$(id -u)" = "0" ] || { echo "ERROR: must run as uid 0 (TOS admin)"; exit 1; }
[ -s "$PKG" ] || { echo "ERROR: package not found: $PKG"; exit 1; }

echo "== 0/8  preflight"
command -v dpkg >/dev/null && ok "dpkg present"
pgrep -x nginx >/dev/null && ok "TOS nginx running"
note "web root: $WEB  package: $PKG"

# safety: keep a copy of existing user data before the uninstall phase
BACKUP=""
if [ -d "$DATA_DIR" ]; then
  BACKUP="/tmp/alist-e2e-backup-$(date +%s).tgz"
  tar czf "$BACKUP" -C /var/lib "$APP_ID" 2>/dev/null && note "existing data backed up to $BACKUP"
fi

echo
echo "== 1/8  install (dpkg -i; also covers the upgrade path if already installed)"
if dpkg -i "$PKG" >/tmp/alist-dpkg.log 2>&1; then ok "dpkg -i succeeded"; else bad "dpkg -i failed"; tail -5 /tmp/alist-dpkg.log; fi
ver=$(dpkg-query -W -f='${Version}' $APP_ID 2>/dev/null)
note "installed version: ${ver:-none}"

echo
echo "== 2/8  service identity and autostart"
systemctl is-active --quiet $APP_ID && ok "service active" || bad "service not active"
systemctl is-enabled --quiet $APP_ID && ok "service enabled (starts after a NAS reboot)" || bad "service not enabled"
pid=$(systemctl show -p MainPID --value $APP_ID 2>/dev/null)
uid=$(awk '/^Uid:/{print $2}' /proc/$pid/status 2>/dev/null)
if [ -n "$uid" ] && [ "$uid" != "0" ]; then ok "runs as uid $uid (non-root)"; else bad "uid=${uid:-unknown} (must be non-root)"; fi
u_name=$(id -un "$uid" 2>/dev/null); [ "$u_name" = "$APP_ID" ] && ok "dedicated user $APP_ID" || bad "unexpected user: $u_name"

echo
echo "== 3/8  listener is loopback only"
ss -tln 2>/dev/null | grep -q "127.0.0.1:$APP_PORT " && ok "listening on 127.0.0.1:$APP_PORT" || bad "not listening on 127.0.0.1:$APP_PORT"
if ss -tln 2>/dev/null | grep -qE "0\.0\.0\.0:$APP_PORT |\[::\]:$APP_PORT "; then
  bad "port $APP_PORT exposed on a public address"
else
  ok "no public listener on $APP_PORT"
fi

echo
echo "== 4/8  platform route, privacy page, WebDAV"
code=$(curl $CURLK -s -o /dev/null -w '%{http_code}' -m 8 "$WEB/$APP_ID/")
case "$code" in 200) ok "GET /$APP_ID/ -> 200";; *) bad "GET /$APP_ID/ -> $code";; esac
pp="$WEB/$APP_ID/privacy-policy.html"
code=$(curl $CURLK -s -o /dev/null -w '%{http_code}' -m 8 "$pp")
[ "$code" = "200" ] && ok "privacy policy served -> 200" || bad "privacy policy -> $code"
body=$(curl $CURLK -s -m 8 "$pp")
for needle in "Privacy Policy" "Retention" "Third-party" "Deletion" "Security"; do
  if printf '%s' "$body" | grep -qi "$needle"; then ok "privacy policy covers '$needle'"; else bad "privacy policy lacks '$needle'"; fi
done
code=$(curl $CURLK -s -o /dev/null -w '%{http_code}' -m 8 -X PROPFIND "$WEB/$APP_ID/dav/")
[ "$code" = "401" ] && ok "WebDAV answers 401 without credentials (auth required)" || note "WebDAV -> $code"

echo
echo "== 5/8  first login with the generated password"
pwf="$DATA_DIR/admin_password.txt"
if [ -f "$pwf" ]; then
  perm=$(stat -c '%a %U' "$pwf" 2>/dev/null)
  [ "$perm" = "600 root" ] && ok "password file 0600 root" || bad "password file perms: $perm"
  pw=$(cat "$pwf")
  code=$(curl $CURLK -s -o /dev/null -w '%{http_code}' -m 8 -X POST -H 'Content-Type: application/json' \
        -d "{\"username\":\"admin\",\"password\":\"$pw\"}" "$WEB/$APP_ID/api/v1/auth/login")
  [ "$code" = "200" ] && ok "admin login -> 200" || bad "admin login -> $code"
else
  bad "password file missing: $pwf"
fi

echo
echo "== 6/8  P1 identity (publisher == deb Maintainer)"
ctrl=$(dpkg-deb -f "$PKG" Maintainer 2>/dev/null)
pub=$(python3 -c "import json;print(json.load(open('$APP_DIR/config.ini')).get('publisher',''))" 2>/dev/null)
mname=${ctrl%% <*}
if [ -n "$pub" ] && [ "$pub" = "$mname" ]; then ok "publisher '$pub' == Maintainer '$mname'"; else bad "publisher '$pub' != Maintainer '$mname'"; fi
note "deb Maintainer: $ctrl"

echo
echo "== 7/8  upgrade keeps data"
marker="$DATA_DIR/e2e-marker-$$"
mkdir -p "$DATA_DIR" && echo "upgrade-marker" > "$marker" 2>/dev/null
dpkg -i "$PKG" >/tmp/alist-dpkg2.log 2>&1
[ -f "$marker" ] && ok "reinstall/upgrade kept the data directory" || bad "data directory lost on upgrade"
[ -f "$pwf" ] && ok "password file survived the upgrade" || bad "password file lost on upgrade"
rm -f "$marker"
systemctl is-active --quiet $APP_ID && ok "service active after upgrade" || bad "service not active after upgrade"

echo
echo "== 8/8  uninstall leaves nothing behind (F11)"
dpkg --remove $APP_ID >/tmp/alist-remove.log 2>&1
[ -d "$DATA_DIR" ] && bad "residual data directory $DATA_DIR" || ok "data directory removed"
[ -e "/etc/systemd/system/$APP_ID.service" ] && bad "residual systemd unit" || ok "systemd unit removed"
[ -e "/etc/nginx/conf.d/$APP_ID.conf" ] && bad "residual nginx route" || ok "nginx route removed"
[ -d "$APP_DIR" ] && bad "residual install dir $APP_DIR" || ok "install dir removed"
if id -u $APP_ID >/dev/null 2>&1; then bad "residual system user $APP_ID"; else ok "system user removed"; fi
[ -e "$MAINT_LOG" ] && bad "residual maintenance log" || ok "maintenance log removed"
if systemctl is-active --quiet $APP_ID; then bad "service still active"; else ok "service gone"; fi
nginx -t >/dev/null 2>&1 && ok "nginx configuration still valid" || bad "nginx config broken after removal"

if [ "$KEEP" = 1 ]; then
  echo
  echo "== reinstall (--keep)"
  dpkg -i "$PKG" >/tmp/alist-dpkg3.log 2>&1
  sleep 3
  systemctl is-active --quiet $APP_ID && ok "service active after reinstall" || bad "service not active after reinstall"
  code=$(curl $CURLK -s -o /dev/null -w '%{http_code}' -m 10 "$WEB/$APP_ID/")
  [ "$code" = "200" ] && ok "web UI reachable after reinstall ($code)" || bad "web UI -> $code after reinstall"
fi

echo
echo "== result"
echo "   open      : $WEB/$APP_ID/"
echo "   data      : $DATA_DIR"
echo "   logs      : journalctl -u $APP_ID -n 50"
echo "   password  : cat $DATA_DIR/admin_password.txt"
[ -n "$BACKUP" ] && echo "   backup    : $BACKUP (previous data, taken before the uninstall test)"
echo "   passed $PASS, failed $FAIL"
[ "$FAIL" = 0 ]
