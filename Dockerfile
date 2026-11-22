# ghostdev — Claude Code in your browser.
# Single image: ttyd + tmux + nginx + the stats backend, optionally with Claude Code preinstalled.
FROM debian:bookworm-slim

ARG TARGETARCH
ARG TTYD_VERSION=1.7.7
# Set to "false" to build a vanilla web terminal without the Claude Code CLI.
ARG INSTALL_CLAUDE=true
# Set to "false" to skip the cc-switch CLI (https://github.com/SaladDay/cc-switch-cli).
ARG INSTALL_CC_SWITCH=true
# Set to "false" to skip the Orca headless server (https://github.com/stablyai/orca).
ARG INSTALL_ORCA=true
# Tool versions: "latest" (default) resolves at build time; pin for reproducible builds, e.g.
#   --build-arg ORCA_VERSION=v1.4.266 --build-arg CLAUDE_CODE_VERSION=2.1.0 --build-arg CC_SWITCH_VERSION=v4.6.0
ARG CLAUDE_CODE_VERSION=latest
ARG CC_SWITCH_VERSION=latest
ARG ORCA_VERSION=latest
# Swap the Debian mirror if deb.debian.org is slow/unreachable, e.g.
# --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn
ARG APT_MIRROR=deb.debian.org
ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i "s|deb.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get update -o Acquire::Retries=5 \
    && apt-get install -y --no-install-recommends -o Acquire::Retries=5 \
      nginx-light tmux ca-certificates curl gettext-base tini procps git less openssh-server \
    && rm -rf /var/lib/apt/lists/*

# ttyd static release binary (multi-arch).
RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    case "$arch" in amd64) t=x86_64;; arm64) t=aarch64;; arm) t=arm;; *) t=x86_64;; esac; \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${t}" -o /usr/local/bin/ttyd; \
    chmod +x /usr/local/bin/ttyd; \
    /usr/local/bin/ttyd --version

# Node.js via nvm (instead of Debian's apt nodejs). nvm lives in /opt/nvm and is chowned to uid 1000
# below, so the non-root user can `nvm install`/`npm i -g`/self-update. Kept outside $HOME because
# $HOME is a persisted volume. /opt/ghost-node is a stable symlink to the installed version's dir
# so PATH works in non-interactive shells (tini/entrypoint, ssh) without sourcing nvm.sh.
# NPM_CONFIG_PREFIX must stay unset: nvm refuses to run when it is set.
ARG NVM_VERSION=v0.40.3
ARG NODE_VERSION=24
ARG PNPM_VERSION=latest
ENV NVM_DIR=/opt/nvm \
    PATH=/opt/ghost-bin:/opt/ghost-node/bin:$PATH
RUN set -ex; \
    mkdir -p "$NVM_DIR" /opt/ghost-bin /opt/orca-server; \
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | PROFILE=/dev/null bash; \
    . "$NVM_DIR/nvm.sh"; \
    nvm install "$NODE_VERSION"; \
    nvm alias default "$NODE_VERSION"; \
    ln -s "$(dirname "$(dirname "$(nvm which "$NODE_VERSION")")")" /opt/ghost-node; \
    npm install -g "pnpm@${PNPM_VERSION}"; \
    npm cache clean --force; \
    nvm cache clear; \
    node --version; npm --version; pnpm --version

# Claude Code CLI (the whole point). Skip with --build-arg INSTALL_CLAUDE=false.
RUN if [ "$INSTALL_CLAUDE" = "true" ]; then \
      npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" && npm cache clean --force; \
      claude --version; \
    fi

# cc-switch CLI — switch Claude Code provider configs from the terminal.
# Musl release binary (multi-arch). Skip with --build-arg INSTALL_CC_SWITCH=false.
RUN if [ "$INSTALL_CC_SWITCH" = "true" ]; then \
      set -eux; \
      arch="${TARGETARCH:-amd64}"; \
      case "$arch" in arm64) a=arm64;; *) a=x64;; esac; \
      if [ "$CC_SWITCH_VERSION" = "latest" ]; then rel="latest/download"; else rel="download/${CC_SWITCH_VERSION}"; fi; \
      curl -fsSL "https://github.com/SaladDay/cc-switch-cli/releases/${rel}/cc-switch-cli-linux-${a}-musl.tar.gz" -o /tmp/cc-switch-cli.tgz; \
      mkdir -p /tmp/cc-switch-cli; \
      tar -xzf /tmp/cc-switch-cli.tgz -C /tmp/cc-switch-cli; \
      mv /tmp/cc-switch-cli/cc-switch /opt/ghost-bin/cc-switch; \
      chmod +x /opt/ghost-bin/cc-switch; \
      rm -rf /tmp/cc-switch-cli /tmp/cc-switch-cli.tgz; \
      /opt/ghost-bin/cc-switch --version; \
    fi

# Orca headless server (server-only tarball: bundles orcad + Node + the `orca-ide` CLI, no GTK/X11).
# The CLI is named `orca-ide` on Linux. The archive is verified against the sha256 file of the same release.
# Skip with --build-arg INSTALL_ORCA=false; pin with --build-arg ORCA_VERSION=v1.4.266.
RUN if [ "$INSTALL_ORCA" = "true" ]; then \
      set -eux; \
      arch="${TARGETARCH:-amd64}"; \
      case "$arch" in arm64) a=arm64;; *) a=x64;; esac; \
      if [ "$ORCA_VERSION" = "latest" ]; then rel="latest/download"; else rel="download/${ORCA_VERSION}"; fi; \
      base="https://github.com/stablyai/orca/releases/${rel}"; \
      f="orca-server-linux-${a}.tar.gz"; \
      mkdir -p /tmp/orca; cd /tmp/orca; \
      curl -fsSL -O "$base/$f" -O "$base/orca-server-sha256sums.txt"; \
      grep -F "$f" orca-server-sha256sums.txt | sha256sum --check -; \
      mkdir -p /opt/orca-server; \
      tar -xzf "$f" -C /opt/orca-server --strip-components=1; \
      ln -s /opt/orca-server/bin/orca-ide /opt/ghost-bin/orca-ide; \
      cd /; rm -rf /tmp/orca; \
      /opt/ghost-bin/orca-ide --version; \
    fi

# UTF-8 locale. debian-slim defaults to POSIX, where tmux renders every non-ASCII
# character (Chinese UI of cc-switch, Claude Code, ...) as "_". C.UTF-8 ships with libc.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Non-root runtime user.
# sshd runs unprivileged as ghost (see entrypoint): '*' = no usable password but NOT locked
# (so pubkey login works); /run/sshd is the privsep dir; /etc/profile.d re-adds the node/nvm PATH
# and UTF-8 locale for SSH login shells (which reset PATH via /etc/profile).
RUN useradd -m -s /bin/bash -u 1000 ghost \
    && usermod -p '*' ghost \
    && mkdir -p /run/sshd && chown ghost:ghost /run/sshd \
    && rm -f /etc/ssh/ssh_host_*_key* \
    && echo 'export PATH=/opt/ghost-bin:/opt/ghost-node/bin:$PATH' > /etc/profile.d/ghostdev.sh \
    && echo 'export NVM_DIR=/opt/nvm' >> /etc/profile.d/ghostdev.sh \
    && echo 'export LANG=C.UTF-8 LC_ALL=C.UTF-8' >> /etc/profile.d/ghostdev.sh

COPY web/                       /var/www/ghostdev/
COPY stats/                     /opt/ghostdev-stats/
COPY config/tmux.conf           /home/ghost/.tmux.conf
COPY config/bashrc.snippet      /tmp/bashrc.snippet
COPY docker/nginx.conf.tmpl     /etc/nginx/templates/ghostdev.conf.tmpl
COPY docker/entrypoint.sh       /usr/local/bin/ghostdev-entrypoint

# Strip CR from files COPYed from a possibly CRLF (Windows) checkout, then wire up the user env.
RUN sed -i -e 's/\r$//' /usr/local/bin/ghostdev-entrypoint /tmp/bashrc.snippet \
             /home/ghost/.tmux.conf /etc/nginx/templates/ghostdev.conf.tmpl \
    && cat /tmp/bashrc.snippet >> /home/ghost/.bashrc \
    && rm /tmp/bashrc.snippet \
    && chmod +x /usr/local/bin/ghostdev-entrypoint \
    && chown -R ghost:ghost /home/ghost /opt/ghostdev-stats /var/www/ghostdev /opt/nvm /opt/ghost-bin /opt/orca-server

USER ghost
WORKDIR /home/ghost
EXPOSE 7680 2222

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/ghostdev-entrypoint"]
