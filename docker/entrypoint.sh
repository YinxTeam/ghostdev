#!/usr/bin/env bash
# ghostdev container entrypoint: render nginx config, then run stats + ttyd + nginx,
# supervising all three so the container restarts if any of them dies.
set -euo pipefail

export GHOSTDEV_NODE_LABEL="${GHOSTDEV_NODE_LABEL:-$(hostname)}"
NGINX_LISTEN=7680
TTYD_PORT=7681
STATS_PORT="${GHOSTDEV_STATS_PORT:-9090}"
export GHOSTDEV_STATS_PORT="$STATS_PORT"
export GHOSTDEV_STATS_BIND=127.0.0.1

mkdir -p /tmp/ghostdev/body /tmp/ghostdev/proxy /tmp/ghostdev/fastcgi /tmp/ghostdev/uwsgi /tmp/ghostdev/scgi

# Render the nginx config (only our placeholders; nginx $vars are preserved).
export NGINX_LISTEN STATS_PORT TTYD_PORT
envsubst '${NGINX_LISTEN} ${STATS_PORT} ${TTYD_PORT}' \
  < /etc/nginx/templates/ghostdev.conf.tmpl > /tmp/ghostdev/nginx.conf

# xterm.js theme for ttyd (matches the GHOST.dev palette).
THEME='{"background":"#0F1117","foreground":"#E6E9F0","cursor":"#3DE3A0","selectionBackground":"#262B38","black":"#161922","red":"#FF5C6C","green":"#3DE3A0","yellow":"#F5B544","blue":"#5BC8FF","magenta":"#9C8CFF","cyan":"#7CF0C2","white":"#C7CDDA","brightBlack":"#3A4150","brightGreen":"#5CEAB0","brightWhite":"#F5F7FC"}'

# Optional ttyd basic auth: GHOSTDEV_BASIC_AUTH="user:pass"
TTYD_CRED=()
if [ -n "${GHOSTDEV_BASIC_AUTH:-}" ]; then
  TTYD_CRED=(-c "$GHOSTDEV_BASIC_AUTH")
fi

# Command each tab runs. Default: attach-or-create a tmux session named by the ?arg= query.
SHELL_CMD=${GHOSTDEV_SHELL:-"tmux new -A -s"}

node /opt/ghostdev-stats/server.js &
STATS_PID=$!

# shellcheck disable=SC2086  # SHELL_CMD is intentionally word-split into args
ttyd -p "$TTYD_PORT" -i 127.0.0.1 -b /tty -a -W "${TTYD_CRED[@]}" \
  -t fontSize=14 -t "fontFamily=JetBrains Mono, Cascadia Mono, Consolas, Menlo, Microsoft YaHei, PingFang SC, Noto Sans Mono CJK SC, monospace" -t disableLeaveAlert=true \
  -t "theme=$THEME" \
  $SHELL_CMD &
TTYD_PID=$!

nginx -c /tmp/ghostdev/nginx.conf &
NGINX_PID=$!

# Optional SSH (key-only, unprivileged sshd as this user). Enabled only when
# GHOSTDEV_SSH_PUBKEY is set; several keys may be separated by newlines or a literal backslash-n.
SSHD_PID=""
if [ -n "${GHOSTDEV_SSH_PUBKEY:-}" ]; then
  SSH_PORT="${GHOSTDEV_SSH_PORT:-2222}"
  SSH_DIR="$HOME/.ssh"
  HOSTKEY_DIR="$SSH_DIR/hostkeys"   # lives in the persisted $HOME so the host fingerprint is stable
  mkdir -p "$HOSTKEY_DIR"; chmod 700 "$SSH_DIR" "$HOSTKEY_DIR"
  [ -f "$HOSTKEY_DIR/ssh_host_ed25519_key" ] || ssh-keygen -q -t ed25519 -N '' -f "$HOSTKEY_DIR/ssh_host_ed25519_key"
  printf '%b\n' "$GHOSTDEV_SSH_PUBKEY" > "$SSH_DIR/authorized_keys"
  chmod 600 "$SSH_DIR/authorized_keys"
  cat > /tmp/ghostdev/sshd_config <<SSHD
Port $SSH_PORT
HostKey $HOSTKEY_DIR/ssh_host_ed25519_key
PidFile /tmp/ghostdev/sshd.pid
AuthorizedKeysFile $SSH_DIR/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
UsePAM no
StrictModes yes
AllowUsers $(id -un)
PrintMotd no
SSHD
  /usr/sbin/sshd -D -e -f /tmp/ghostdev/sshd_config &
  SSHD_PID=$!
  echo "ghostdev ssh: sshd :$SSH_PORT (key-only, user $(id -un))"
fi

cleanup(){ kill "$STATS_PID" "$TTYD_PID" "$NGINX_PID" $SSHD_PID 2>/dev/null || true; }
trap cleanup EXIT INT TERM

echo "ghostdev up: nginx :$NGINX_LISTEN -> ttyd :$TTYD_PORT + stats :$STATS_PORT (label=$GHOSTDEV_NODE_LABEL)"

# If any of the services exits, tear the rest down and exit non-zero so Docker restarts us.
wait -n
exit 1
