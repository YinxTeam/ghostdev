<div align="center">

<img src="web/ghost-mark.png" alt="ghostdev" width="84">

# GHOST.dev

### 在浏览器中运行 Claude Code —— 一个自托管、多会话的 Web 终端，告诉你哪个智能体需要你。

[English README](README.md)

[![Stars](https://img.shields.io/github/stars/YinxTeam/ghostdev?style=flat&color=3DE3A0&logo=github)](https://github.com/YinxTeam/ghostdev/stargazers)
[![Issues](https://img.shields.io/github/issues/YinxTeam/ghostdev?color=5BC8FF)](https://github.com/YinxTeam/ghostdev/issues)
[![Last commit](https://img.shields.io/github/last-commit/YinxTeam/ghostdev?color=9C8CFF)](https://github.com/YinxTeam/ghostdev/commits/main)
[![License: MIT](https://img.shields.io/badge/License-MIT-3DE3A0.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/run-docker%20compose-5BC8FF.svg)](#快速开始)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-3DE3A0.svg)](#贡献)
[![Built with Claude Code](https://img.shields.io/badge/built%20with-Claude%20Code-9C8CFF.svg)](https://claude.com/claude-code)

</div>

---

打开一个标签页，输入 `claude`，你就能在浏览器里获得一个完整的 Claude Code 会话 —— 背后是一个**持久的 tmux 会话**，刷新页面、断开连接甚至重启都不会丢失。再开一个标签页处理另一个仓库，第三个……**每个标签页上的状态小圆点会实时告诉你该会话里的 Claude 正在做什么** —— 工作中、等你发消息、还是卡在权限提示上 —— 这样当你同时操控多个智能体时，一眼就能看出哪个需要你。

后者才是重点。普通的 Web 终端（ttyd、wetty、gotty）只是给你一个浏览器里的 shell。ghostdev 给你的是一个**管理并行 Claude Code 会话的仪表盘**。

<p align="center">
  <img src="assets/hero.gif" alt="GHOST.dev：标签页状态小圆点会随着每个 Claude 会话的工作、等待输入或需要权限而实时变化" width="100%">
</p>

<div align="center">

[为什么](#为什么) · [对比](#对比) · [特性](#特性) · [快速开始](#快速开始) · [配置](#配置) · [原生安装（不使用 Docker）](#原生安装不使用-docker) · [工作原理](#工作原理) · [贡献](#贡献)

</div>

## 为什么

并行运行多个 Claude Code 会话已经是常态 —— 一个仓库一个、一个功能一个、一个实验一个。问题不在于启动它们，而在于**知道哪个卡在那儿等你**，其他的还在继续跑。ghostdev 就是把这件事摆在台面上：

- 🟢 **绿色圆点** —— Claude 空闲，在等你发下一条消息
- ⚪ **灰色圆点** —— Claude 正在工作（思考 / 生成 / 运行工具）
- 🟠 **琥珀色圆点（闪烁）** —— Claude 被权限提示卡住了 → 去批准吧
- 浏览器标签页标题还会显示一个关注计数器，比如 `(2) GHOST.dev`

## 对比

|  | **ghostdev** | ttyd / wetty / gotty | code-server |
|---|:---:|:---:|:---:|
| Web 终端 | ✅ | ✅ | ⚠️ 完整 IDE |
| 多会话标签页 | ✅ | ❌ 单个 shell | ➖ |
| 每个标签页独立持久 tmux | ✅ | ❌ | ❌ |
| **每个标签页的 Claude 状态**（工作 / 等待 / 需要权限） | ✅ | ❌ | ❌ |
| 重新打开 / 杀掉已分离的会话 | ✅ | ❌ | ➖ |
| 顶部栏实时系统状态 | ✅ | ❌ | ❌ |
| 预装 Claude Code | ✅ | ❌ | ❌ |
| 资源占用 | 极小（ttyd + nginx + Node） | 极小 | 较重 |

## 特性

- **浏览器标签页 → tmux 会话。** 每个标签页对应一个"附加或新建"的 tmux 会话。关闭标签页后会话继续运行；稍后重新打开，就能从离开的地方继续。
- **感知 Claude 的状态圆点**（每个标签页）+ 标题栏关注计数器。（[工作原理](docs/claude-status.zh-CN.md)）
- **"已关闭会话"抽屉** —— 所有未以标签页形式打开的活跃会话，可以随时重新打开或杀掉。
- **顶部栏实时状态** —— 宿主机的 CPU / 内存 / 磁盘以及它的 IP。（[可选的 Proxmox 宿主机状态](docs/proxmox-stats.zh-CN.md)）
- **内置文件管理器** —— 侧边面板，可浏览、上传、下载（或直接从 URL 拉取）、重命名、删除和编辑文件，被限制在可配置的根目录内。（[文档](docs/file-explorer.zh-CN.md)）
- **多语言 UI** —— 英语、西班牙语、葡萄牙语、法语自动检测，顶部栏带切换器，易于扩展。
- **全部持久化** —— 会话、滚动缓冲区、shell 历史和 Claude Code 登录状态在重启后都保留（Docker 卷 / 原生安装的 home 目录）。
- **一个镜像，一条命令。** ttyd + tmux + nginx + 一个轻量 Node 后端，预装 Claude Code。
- **精心调校的暗色主题**，调优的 `tmux` 和 `bash` 配置，JetBrains Mono 字体，移动端友好布局。

<p align="center">
  <img src="assets/file-explorer.png" alt="内置文件管理器侧边面板在终端旁边打开" width="49%">
  <img src="assets/sessions.png" alt="已关闭会话抽屉：未以标签页打开的活跃 tmux 会话" width="49%">
</p>

## 快速开始

```bash
git clone https://github.com/YinxTeam/ghostdev.git
cd ghostdev
cp .env.example .env          # 按喜好调整 label / 端口
docker compose up -d
```

打开 **http://127.0.0.1:7680**，点 **+**，输入 `claude`，登录。完成。

> 首次运行需要下载 ttyd 二进制并把 Claude Code 装进镜像，所以首次构建大概需要一分钟。之后就是秒起。

### ⚠️ 暴露到外网之前

Web 终端本质上是**远程 shell**。ghostdev 故意只绑定到 `127.0.0.1`。要从其他机器访问，请把它放在 VPN 后面，或者放在带认证的反向代理后面 —— **别**直接绑到公网 IP。这件事很重要；读一读 **[docs/SECURITY.zh-CN.md](docs/SECURITY.zh-CN.md)**（很短）。

## 配置

全部通过 `.env` 设置（参考 [`.env.example`](.env.example)）：

| 变量 | 默认值 | 作用 |
|---|---|---|
| `GHOSTDEV_HOST_ADDR` | `127.0.0.1` | 容器发布到的主机地址 |
| `GHOSTDEV_HOST_PORT` | `7680` | 主机端口 |
| `GHOSTDEV_NODE_LABEL` | hostname | 顶部栏显示的标签 |
| `GHOSTDEV_SHOW_PUBLIC_IP` | `true` | 在顶部栏显示 WAN IP（调用 api.ipify.org） |
| `GHOSTDEV_BASIC_AUTH` | _(空)_ | 可选的 `user:pass` HTTP 基础认证 |
| `GHOSTDEV_SHELL` | `tmux new -A -s` | 每个标签页启动时执行的命令 |
| `GHOSTDEV_FILES_ENABLED` | `true` | 内置文件管理器（[文档](docs/file-explorer.zh-CN.md)） |
| `GHOSTDEV_FILES_ROOT` | 用户 home | 文件管理器被限制到的目录 |
| `GHOSTDEV_FILES_READONLY` | `false` | `true` = 只能浏览/下载，UI 上无法写入 |
| `GHOSTDEV_PROXMOX_*` | _(关闭)_ | 可选的只读 Proxmox 宿主机状态（[文档](docs/proxmox-stats.zh-CN.md)） |

构建不包含 Claude Code 的版本（纯 Web 终端）：`docker compose build --build-arg INSTALL_CLAUDE=false`。
构建不包含 [cc-switch](https://github.com/SaladDay/cc-switch-cli) CLI 的版本：`docker compose build --build-arg INSTALL_CC_SWITCH=false`。
当 deb.debian.org 慢或不稳定时，可换用更快的 Debian 镜像源：`docker compose build --build-arg APT_MIRROR=mirrors.tuna.tsinghua.edu.cn`。

## 原生安装（不使用 Docker）

把 ttyd + nginx + 状态后端作为 systemd 服务安装：

```bash
sudo ./install/install.sh --user youruser --port 7680 --label my-box
```

运行 `./install/install.sh --help` 查看全部选项。默认也绑定到 `127.0.0.1` —— 安全注意事项同上。

## 工作原理

```
                 ┌───────────────────────── nginx ─────────────────────────┐
  浏览器 ─────▶ │  /            → 静态 UI  (web/index.html，仪表盘)          │
                 │  /tty   (ws)  → ttyd :7681 → tmux 附加或新建会话           │
                 │  /api/* (json)→ stats :9090 (CPU/内存/磁盘、会话状态)     │
                 └──────────────────────────────────────────────────────────┘
```

- **ttyd** 负责提供终端；URL 中的 `?arg=<name>` 会被用作 tmux 会话名，因此每个标签页都映射到自己的持久会话。
- **`stats/server.js`**（纯 Node 标准库，零依赖）提供 `/stats`，列出所有 tmux 会话（通过抓取可见面板来标注每个会话的 Claude 状态），并在 `/api/fs/*` 后提供文件管理器（列表 / 读 / 上传 / 重命名 / 删除 / 抓取 URL），被限制在 `GHOSTDEV_FILES_ROOT` 内。没有密钥，没有外部服务。
- 仪表盘（`web/index.html`）管理标签页、已关闭会话抽屉、文件面板、顶部栏实时状态，以及英/西/葡/法四种语言的翻译。

## 路线图

- [ ] 会话状态变成 `perms` 或 `input` 时可选的桌面/Web 推送
- [ ] 每个会话独立的工作目录 / 仓库标签
- [ ] 主题切换器
- [ ] 可插拔的其他 CLI 智能体状态检测器

## 贡献

欢迎 Issue 和 PR —— Bug 报告、为其他 CLI 智能体编写状态检测器、主题、或更多发行版的打包。提交状态检测相关的 Bug？请附上被误判会话的 `tmux capture-pane -p` 输出（见 [docs/claude-status.zh-CN.md](docs/claude-status.zh-CN.md)），这样很容易修复。

如果 ghostdev 对你有用，**点个 ⭐ 可以让更多人发现它。**

## 致谢

站在 [ttyd](https://github.com/tsl0922/ttyd)、[tmux](https://github.com/tmux/tmux)、[nginx](https://nginx.org) 和 [Claude Code](https://claude.com/claude-code) 的肩膀上。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。

## Star 历史

<a href="https://star-history.com/#YinxTeam/ghostdev&Date">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=YinxTeam/ghostdev&type=Date&theme=dark" />
    <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=YinxTeam/ghostdev&type=Date" />
    <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=YinxTeam/ghostdev&type=Date" width="600" />
  </picture>
</a>
