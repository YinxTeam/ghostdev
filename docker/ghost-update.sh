#!/usr/bin/env bash
# Update the bundled tools in place, without rebuilding the image.
# Usage: ghost-update [orca|cc-switch|claude|all] [version]   (default: all, latest)
# Everything lives in ghost-owned dirs (/opt/orca-server, /opt/ghost-bin, /opt/nvm), so no root needed.
# Each tool is skipped when already current. Failures in one tool don't stop the others.
# Also run daily by the entrypoint (see GHOSTDEV_AUTOUPDATE in docs).
set -uo pipefail

which_tool="${1:-all}"
want="${2:-latest}"
case "$(uname -m)" in aarch64|arm64) a=arm64;; *) a=x64;; esac
log(){ echo "ghost-update: $*"; }

# Resolve "latest" to a tag by following the GitHub redirect (no API rate limit / no jq needed).
latest_tag(){ curl -fsSIL -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest" | sed 's#.*/tag/##'; }

# True if the installed `--version` output already contains version $2 (leading "v" ignored).
is_current(){ "$1" --version 2>&1 | grep -qF "${2#v}"; }

update_orca(){
  command -v orca-ide >/dev/null 2>&1 || { log "orca: not installed, skipping"; return 0; }
  local tag="$want"; [ "$tag" = latest ] && tag="$(latest_tag stablyai/orca)"
  [ -n "$tag" ] || { log "orca: cannot resolve latest version"; return 1; }
  is_current orca-ide "$tag" && { log "orca: up to date ($tag)"; return 0; }
  log "orca: updating to $tag"
  local base="https://github.com/stablyai/orca/releases/download/${tag}"
  local f="orca-server-linux-${a}.tar.gz" tmp; tmp="$(mktemp -d)"
  (
    cd "$tmp" && set -e
    curl -fsSL -O "$base/$f" -O "$base/orca-server-sha256sums.txt"
    grep -F "$f" orca-server-sha256sums.txt | sha256sum --check -
    mkdir new && tar -xzf "$f" -C new --strip-components=1
    ./new/bin/orca-ide --version >/dev/null          # refuse to swap in a broken build
    # /opt is root-owned, so replace the contents rather than renaming the directory.
    find /opt/orca-server -mindepth 1 -delete
    cp -a new/. /opt/orca-server/
  ); local rc=$?
  rm -rf "$tmp"
  [ $rc -eq 0 ] || { log "orca: update FAILED"; return 1; }
  log "orca: now $(orca-ide --version 2>&1 | head -n1)"
  # The entrypoint supervisor loop restarts `orca-ide serve` within ~5s on the new binaries.
  pkill -f 'orca-ide serve|orcad' 2>/dev/null && log "orca: restarting"
  return 0
}

update_cc_switch(){
  command -v cc-switch >/dev/null 2>&1 || { log "cc-switch: not installed, skipping"; return 0; }
  local tag="$want"; [ "$tag" = latest ] && tag="$(latest_tag SaladDay/cc-switch-cli)"
  [ -n "$tag" ] || { log "cc-switch: cannot resolve latest version"; return 1; }
  is_current cc-switch "$tag" && { log "cc-switch: up to date ($tag)"; return 0; }
  log "cc-switch: updating to $tag"
  local tmp; tmp="$(mktemp -d)"
  (
    cd "$tmp" && set -e
    curl -fsSL "https://github.com/SaladDay/cc-switch-cli/releases/download/${tag}/cc-switch-cli-linux-${a}-musl.tar.gz" -o cc.tgz
    mkdir x && tar -xzf cc.tgz -C x
    chmod +x x/cc-switch && ./x/cc-switch --version >/dev/null
    mv -f x/cc-switch /opt/ghost-bin/cc-switch        # rename over a running binary is safe
  ); local rc=$?
  rm -rf "$tmp"
  [ $rc -eq 0 ] && log "cc-switch: now $(cc-switch --version 2>&1 | head -n1)" || { log "cc-switch: update FAILED"; return 1; }
}

update_claude(){
  command -v claude >/dev/null 2>&1 || { log "claude: not installed, skipping"; return 0; }
  local v="$want"; [ "$v" = latest ] && v="$(npm view @anthropic-ai/claude-code version 2>/dev/null)"
  [ -n "$v" ] || { log "claude: cannot resolve latest version"; return 1; }
  is_current claude "$v" && { log "claude: up to date ($v)"; return 0; }
  log "claude: updating to $v"
  npm install -g "@anthropic-ai/claude-code@${v}" >/dev/null 2>&1 \
    && log "claude: now $(claude --version 2>&1 | head -n1)" || { log "claude: update FAILED"; return 1; }
  npm cache clean --force >/dev/null 2>&1 || true
}

rc=0
case "$which_tool" in
  orca)      update_orca || rc=1 ;;
  cc-switch) update_cc_switch || rc=1 ;;
  claude)    update_claude || rc=1 ;;
  all)       update_claude || rc=1; update_cc_switch || rc=1; update_orca || rc=1 ;;
  *) echo "usage: ghost-update [orca|cc-switch|claude|all] [version]" >&2; exit 2 ;;
esac
exit $rc
