# ghostdev — Claude Code in your browser.
# Single image: ttyd + tmux + nginx + the stats backend, optionally with Claude Code preinstalled.
FROM debian:bookworm-slim

ARG TARGETARCH
ARG TTYD_VERSION=1.7.7
# Set to "false" to build a vanilla web terminal without the Claude Code CLI.
ARG INSTALL_CLAUDE=true
# Set to "false" to skip the cc-switch CLI (https://github.com/SaladDay/cc-switch-cli).
ARG INSTALL_CC_SWITCH=true
# Swap the Debian mirror if deb.debian.org is slow/unreachable, e.g.
# --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn
ARG APT_MIRROR=deb.debian.org
ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i "s|deb.debian.org|${APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get update -o Acquire::Retries=5 \
    && apt-get install -y --no-install-recommends -o Acquire::Retries=5 \
      nginx-light nodejs npm tmux ca-certificates curl gettext-base tini procps git less \
    && rm -rf /var/lib/apt/lists/*

# ttyd static release binary (multi-arch).
RUN set -eux; \
    arch="${TARGETARCH:-amd64}"; \
    case "$arch" in amd64) t=x86_64;; arm64) t=aarch64;; arm) t=arm;; *) t=x86_64;; esac; \
    curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${t}" -o /usr/local/bin/ttyd; \
    chmod +x /usr/local/bin/ttyd; \
    /usr/local/bin/ttyd --version

# Claude Code CLI (the whole point). Skip with --build-arg INSTALL_CLAUDE=false.
RUN if [ "$INSTALL_CLAUDE" = "true" ]; then \
      npm install -g @anthropic-ai/claude-code && npm cache clean --force; \
    fi

# cc-switch CLI — switch Claude Code provider configs from the terminal.
# Musl release binary (multi-arch). Skip with --build-arg INSTALL_CC_SWITCH=false.
RUN if [ "$INSTALL_CC_SWITCH" = "true" ]; then \
      set -eux; \
      arch="${TARGETARCH:-amd64}"; \
      case "$arch" in arm64) a=arm64;; *) a=x64;; esac; \
      curl -fsSL "https://github.com/SaladDay/cc-switch-cli/releases/latest/download/cc-switch-cli-linux-${a}-musl.tar.gz" -o /tmp/cc-switch-cli.tgz; \
      mkdir -p /tmp/cc-switch-cli; \
      tar -xzf /tmp/cc-switch-cli.tgz -C /tmp/cc-switch-cli; \
      mv /tmp/cc-switch-cli/cc-switch /usr/local/bin/cc-switch; \
      chmod +x /usr/local/bin/cc-switch; \
      rm -rf /tmp/cc-switch-cli /tmp/cc-switch-cli.tgz; \
      /usr/local/bin/cc-switch --version; \
    fi

# UTF-8 locale. debian-slim defaults to POSIX, where tmux renders every non-ASCII
# character (Chinese UI of cc-switch, Claude Code, ...) as "_". C.UTF-8 ships with libc.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Non-root runtime user.
RUN useradd -m -s /bin/bash -u 1000 ghost

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
    && chown -R ghost:ghost /home/ghost /opt/ghostdev-stats /var/www/ghostdev

USER ghost
WORKDIR /home/ghost
EXPOSE 7680

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/ghostdev-entrypoint"]
