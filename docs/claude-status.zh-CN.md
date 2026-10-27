# 每个标签页的 Claude 状态是如何工作的

核心特性：每个标签页上的状态圆点会告诉你该会话里的 Claude Code 正在做什么，这样当你同时运行多个会话时，一眼就能看出哪个需要你。

| 圆点 | 状态 | 含义 |
|-----|-------|---------|
| 绿色（发光） | `input` | Claude 空闲在一个空提示符上，**正在等你发消息** |
| 灰色 | `busy` | Claude **正在工作**（思考 / 生成 / 运行工具） |
| 琥珀色（闪烁） | `perms` | Claude **被权限提问卡住了** —— 去批准它吧 |
| 暗灰 | `ended` | Claude 已退出；会话回到了 shell |

当一个非活跃标签页处于 `input` 或 `perms` 状态时，浏览器标签页标题会显示关注计数器，比如 `(2) GHOST.dev — terminal`。

## 工作机制

状态后端（`stats/server.js`）每隔几秒轮询一次。对每个 tmux 会话，它：

1. 运行 `tmux list-panes` 查看前台命令是不是 `claude`（或 `node`）。如果不是 → `ended`。
2. 运行 `tmux capture-pane -p` 读取可见屏幕内容，剥掉 ANSI 转义，然后用三条正则匹配：
   - `RE_PERMS` —— Claude 的权限提示（`Do you want to proceed…`、`Yes, and don't ask again`、编号的 `❯ 1. Yes`……）→ `perms`
   - `RE_BUSY` —— 工作中的 spinner / token 计数 / `esc to interrupt` → `busy`
   - `RE_READY` —— 一个孤立的空 `❯` 提示符 → `input`
3. 还活着但没匹配上任何正则的，默认归为 `busy`。

## 调整正则

Claude Code 的 spinner 文案和提示符措辞会随版本变化，所以这些正则就是 **`stats/server.js` 顶部的普通常量**，很容易找到和修改：

```js
const RE_PERMS = /Do you want to (?:proceed|make|create|run|allow|apply|edit|overwrite|delete)|.../i;
const RE_BUSY  = /esc to interrupt|[↓↑]\s*[\d.,]+\s*k?\s*tokens|.../;
const RE_READY = /^\s*❯\s*$/m;
```

如果某个新版本的 Claude 显示状态不正确，就在那个状态下抓一个面板（`tmux capture-pane -p -t <session>`），把漏掉的短语加进去就好。这是基于终端屏幕内容的启发式匹配 —— 官方没有提供 API —— 所以请把它视为尽力而为。

这也意味着这个特性不限于 Claude：把正则指向任何交互式 CLI 智能体，圆点就能跟踪它的状态。
