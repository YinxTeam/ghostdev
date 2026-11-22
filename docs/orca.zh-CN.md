# Orca 无头服务器

镜像内置了 [Orca](https://github.com/stablyai/orca) 的 **server-only** 版本(Linux 下的命令行叫 `orca-ide`,因为 `/usr/bin/orca` 被 GNOME 读屏器占用)。容器启动后会默认运行 `orca-ide serve`,登录 Orca 账号并配对后,你可以在手机或其他设备上通过 **Orca Relay** 从任意网络远程使用,**不需要映射任何端口、不需要公网 IP**。

> Orca 官方把 Remote Orca Servers 标为 beta。server-only 版本没有浏览器面板和语音输入。

## 一次性设置

容器启动后,执行两步(都需要交互,所以用 `-it`):

```bash
# 1. 登录 Orca 账号:打印一个链接,在任意浏览器里登录,把页面上的验证码粘贴回终端
docker exec -it ghostdev orca-ide auth login

# 2. 生成手机配对二维码/链接(走 Orca Relay)
docker exec -it ghostdev orca-ide pair --mobile --relay
```

然后在手机的 Orca 上扫码或粘贴 `orca://pair?...` 链接即可。必须**先启动服务再登录**(默认已随容器启动)。

> 配对链接等同于密码。服务以 supervised 模式运行,不会把它打印到 `docker logs`,请只在需要时用上面的命令生成。

常用命令:

```bash
docker exec -it ghostdev orca-ide auth status   # 查看登录状态
docker exec -it ghostdev orca-ide status        # 查看服务状态
docker exec -it ghostdev orca-ide pair --mobile --relay --rotate   # 作废未使用的配对并重新生成
```

> 具体子命令以 `orca-ide --help` 为准。官方文档:<https://github.com/stablyai/orca/tree/main/docs/site/content/docs>。

## 连接其他电脑(桌面版 Orca)

**手机走 Relay,但桌面版 Orca 不能走 Relay**(`orca-ide pair --relay` 只对 `--mobile` 生效,会报 `--relay applies only with --mobile`)。其他电脑只能直连容器的 6768 端口,有三种办法,**都不要把 6768 直接暴露到公网**:

先在容器里生成"桌面端"配对链接(不带 `--mobile`),`--address` 是客户端实际要连的地址:

```bash
docker exec -it ghostdev orca-ide pair --address <客户端能访问的地址[:端口]>
```

然后在那台电脑的 Orca 里:**Settings → Remote Orca Servers → Add Server**,粘贴 `orca://pair?...` 链接。也可以用命令行:

```bash
orca-ide environment add --name ghostdev --pairing-code 'orca://pair?code=...'
```

### 方式一:SSH 隧道(不需要额外组件,推荐)

复用 ghostdev 自带的仅公钥 SSH(先在 `.env` 里设置 `GHOSTDEV_SSH_PUBKEY`,默认映射宿主机 2222 端口)。

```bash
# 在要连接的那台电脑上:把本地 16768 转发到容器的 6768,保持这个窗口不要关
ssh -N -L 16768:127.0.0.1:6768 -p 2222 ghost@<宿主机地址>

# 在容器里生成链接,告诉客户端连本地转发端口
docker exec -it ghostdev orca-ide pair --address 127.0.0.1:16768
```

本地用 16768 而不是 6768,是为了不和这台电脑上自己的 Orca 冲突。每台电脑各自开隧道,链接可以分别生成。

### 方式二:Tailscale / WireGuard

宿主机和那台电脑都加入同一个 tailnet,然后在 `docker-compose.yml` 的 `ports` 里**只绑定到 Tailscale IP**:

```yaml
      - "100.x.y.z:6768:6768"   # 宿主机的 Tailscale IP
```

```bash
docker exec -it ghostdev orca-ide pair --address 100.x.y.z
```

容器内 Orca 默认接受本机、局域网和 Tailscale 网段的连接,公网地址会被拒绝。

### 方式三:带 TLS 和认证的反向代理

把 `wss://orca.example.com` 反向代理到容器的 6768(需要支持 WebSocket),并在前面放认证,参考 [reverse-proxy.zh-CN.md](reverse-proxy.zh-CN.md):

```bash
docker exec -it ghostdev orca-ide pair --address wss://orca.example.com
```

### 注意

- 每个设备配对后拥有**独立、可撤销**的令牌,其他设备的访问不受影响。链接等同于密码,不要多人共用。
- 容器(服务)重启后,之前未使用的链接无法再次显示,会生成新链接,旧链接依然有效;用 `--rotate` 可作废未使用的旧链接。
- 默认的 `pair`(不带 `--address`)会打印容器内部地址(如 `172.17.0.2`),只在宿主机本机能用,远程设备务必指定 `--address`。
- 以上三种方式里,SSH 隧道和 Tailscale 是按上游文档的做法写的;反向代理方式我没有实际跑通过。

## 网络

- 容器不发布 Orca 的端口(默认 6768)。
- Relay 只需要容器**出站**访问 443 端口:`login.onorca.dev`、`relay.onorca.dev`、`*.relay.onorca.dev`。
- 官方不建议把 6768 直接暴露到公网。其他电脑的接入方式见上一节"连接其他电脑"。

## 配置

| 变量 | 默认 | 作用 |
|---|---|---|
| `GHOSTDEV_ORCA_ENABLE` | `true` | 设为 `false` 则不启动 Orca |
| `GHOSTDEV_WORKSPACE` | `/home/ghost/workspace` | Orca 的项目根目录,自动创建,位于持久化卷中 |

Orca 创建的 agent(如 Claude Code)以 `ghost` 用户运行,直接复用 `~/.claude` 里的登录状态。

构建参数:

```bash
docker compose build --build-arg INSTALL_ORCA=false          # 不安装 Orca
docker compose build --build-arg ORCA_VERSION=v1.4.266       # 固定版本(默认 latest)
```

安装包会用同一个 release 里的 `orca-server-sha256sums.txt` 校验。

## 持久化

Orca 的状态(配对密钥、已配对设备、登录态)保存在 `~/.config/orca`,即 `ghostdev-home` 卷(`/home/ghost`),所以容器重启、镜像升级后无需重新登录和配对。

> 不要克隆这个卷或带着它的镜像到另一个实例:各实例会共用配对身份。需要时执行 `orca-ide serve reset-identity`,或为每个实例设置不同的 `ORCA_INSTANCE_ID`。

## 升级

server-only 版本不能由配对的客户端更新。升级方式:重新构建镜像(默认取最新版本)并重启容器。

## 安全

见 [SECURITY.zh-CN.md](SECURITY.zh-CN.md)。要点:Relay 流量经过 Orca 官方中继;已配对设备拥有 `ghost` 用户的 shell 权限;配对链接要当密码保管。不需要时设置 `GHOSTDEV_ORCA_ENABLE=false`。

## 故障排查

- Orca 崩溃不会影响网页终端,入口脚本会每 5 秒自动重启它,日志见 `docker logs ghostdev`。
- `auth login` 失败:确认服务在运行(`docker exec ghostdev pgrep -fa orca`),且容器能访问 `login.onorca.dev:443`。
- 报 `orcad_identity_mismatch: the server on remote port 6768 is not this host's Orca server`:客户端连到的那个端口上,回应的不是配对时的那台服务器。常见原因:
  1. 隧道的本地端口和这台电脑自己的 Orca(默认也是 6768)冲突,连到了本机的 Orca。隧道请用 16768 之类的空闲端口,并让链接的 `--address` 与之一致;Windows 可用 `netstat -ano | findstr 6768` 检查占用。
  2. 隧道没建成功(`ssh` 已退出、端口被占),或 `--address` 写的端口和隧道端口不一致。
  3. 容器的数据卷被重建/重置过,服务器身份变了,而客户端还保存着旧配对。在客户端删除旧的 Remote Server,重新 `pair` 并添加。
  4. 你用的是 Orca 桌面端自带的 "SSH hosts"(由 Orca 通过 SSH 在远端自己部署、管理服务器)。它会和容器里已经在跑的 Orca 冲突。ghostdev 不要用这个功能,按上面的"SSH 隧道"手动连接。
     之后在 Remote Orca Servers 里无法直接删除这类服务器(报 `Orca runs this server on an SSH host for you`),请在 Settings > Orca on your SSH hosts 里移除,或执行 `orca environment stop --environment <名称> --yes`(会停掉远端那个由桌面端部署的服务器);主机已不存在则用 `orca environment forget --environment <名称> --yes`(只在本机解除关联,不联系主机)。
  5. SSH 连到的不是 ghostdev 容器(例如宿主机的 22 端口,而不是映射的 2222)。
- 已知问题:`--mobile-pairing` 配合窄范围的 `--bind` 会被拒绝(上游 issue #39728)。
