# 安全

ghostdev 给浏览器提供的是宿主机上的**真实 shell**（默认还带 Claude Code CLI，拥有该用户的所有权限）。把它当成 SSH 对待：任何能连上它、并通过认证的人，都能以该用户的身份执行命令。

## 一条铁律

**未经认证，绝对不要把 ghostdev 直接暴露到公网。**

默认设置就是为了让不安全的事情难以发生：

- Docker 容器只发布到 **`127.0.0.1`**（`GHOSTDEV_HOST_ADDR=127.0.0.1`）。
- 原生安装器默认让 nginx 监听 **`127.0.0.1`**（`--bind`）。
- `ttyd` 和状态后端都只绑定 localhost，只能通过 nginx 访问。

要从其他机器访问，请选下面的方式之一 —— 别直接把 bind 改成 `0.0.0.0`。

## 安全暴露的几种方式

1. **VPN / 覆盖网络（最简单）。** 让宿主机接入 Tailscale / WireGuard / ZeroTier，然后通过 `http://<vpn-ip>:7680` 访问。完全没有公网暴露。

2. **反向代理 + SSO（正式环境推荐）。** 前面放 nginx / Caddy / Nginx Proxy Manager 做 TLS 终结，再接身份认证（Authentik、Authelia、Cloudflare Access、oauth2-proxy）。代理在请求到达 ghostdev 之前先强制登录。见 [`reverse-proxy.zh-CN.md`](reverse-proxy.zh-CN.md)。

3. **内置基础认证（最低标准）。** 设置 `GHOSTDEV_BASIC_AUTH=user:强密码`。这会在 ttyd 层加 HTTP 基础认证提示。务必同时启用 TLS（通过反向代理），否则密码会明文传输。还是推荐方案 2。

## 其他注意事项

- **镜像和仓库里没有密钥。** 所有配置都通过环境变量。可选的 Proxmox 状态模块使用**只读 API Token**，绝不会使用 root 密码 —— 见 [`proxmox-stats.zh-CN.md`](proxmox-stats.zh-CN.md)。
- **以非 root 用户运行。** 容器内用 `ghost`（uid 1000）；原生安装用你通过 `--user` 指定的用户。不要让会话以 root 运行。
- **终端能做的就是该用户能做的。** 如果你预装了 Claude Code，通过认证的访问者就可以运行它（并批准它的权限提示）。请合理限制该账号的权限范围。
- **漏洞报告：** 请到 GitHub 仓库发起私有安全 Advisory，而不是公开 Issue。
