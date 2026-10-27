# 可选：Proxmox 宿主机状态

默认情况下，顶部栏显示的是 ghostdev 所在机器的状态（来自 cgroups、`/proc` 和 `df` 的 CPU / 内存 / 磁盘）。如果这台机器是 Proxmox **客户机**（LXC/VM），你也可以在旁边显示 **Proxmox 宿主机**的 CPU / 内存 / 磁盘。

这个模块**默认关闭**，并且使用**只读 API Token** —— 绝不使用 root 密码。

## 1. 创建只读 API Token

在 Proxmox 宿主机上：

```bash
# 专门用于审计的用户
pveum user add ghostdev@pve
pveum acl modify / --users ghostdev@pve --roles PVEAuditor   # 只读
# 为该用户创建一个 token（复制打印出的 secret —— 只显示一次）
pveum user token add ghostdev@pve stats --privsep 0
```

`PVEAuditor` 角色授予读取节点状态的权限；它无法修改任何东西。Token ID 是 `ghostdev@pve!stats`，你会得到一个 secret 值。

## 2. 配置 ghostdev

在你的 `.env` 中：

```ini
GHOSTDEV_PROXMOX_ENABLED=true
GHOSTDEV_PROXMOX_HOST=192.0.2.10            # Proxmox 宿主机的 IP/FQDN（端口 8006）
GHOSTDEV_PROXMOX_TOKEN_ID=ghostdev@pve!stats
GHOSTDEV_PROXMOX_TOKEN_SECRET=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# GHOSTDEV_PROXMOX_NODE=pve                  # 可选；省略时从 /nodes 自动探测
```

重启（`docker compose up -d` 或 `systemctl restart ghostdev-stats`）。顶部栏会出现一个 `// host` 分组和一个 `host` IP。如果 token 错误或宿主机不可达，ghostdev 只会隐藏 host 分组 —— 本地状态仍然正常工作。

> 状态后端通过 HTTPS 与 Proxmox API 通信，但会跳过 TLS 校验（Proxmox 默认自带自签名证书）。Token 是只读的，所以影响范围仅限读取节点状态。
