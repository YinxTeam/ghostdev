# 文件管理器

内置的文件管理器以**侧边面板**的形式从终端旁边滑出（用顶部栏的文件夹图标切换）。它让你无需离开浏览器就能管理文件 —— 上传数据集、抓一份日志、放一个配置文件、修一下文件里的笔误。

## 能做什么

- **浏览**文件夹（面包屑导航，点击路径段即可跳转）。
- **上传** —— 点 *Upload* 或直接把文件拖到面板里。
- **下载**文件，或 **从 URL 下载** —— 粘贴一个链接，服务器直接把它抓进当前文件夹。
- **新建文件夹**、**重命名**、**删除**（文件和文件夹都支持）。
- **查看 / 编辑**文本文件，内置编辑器；图片可内联预览。

## 范围与安全

管理器被限制在**单一的根目录**内（`GHOSTDEV_FILES_ROOT`，默认为应用用户的 home）。所有 API 路径都会做标准化和检查，防止请求越出根目录（`../` 会被清除）。

> 这**不会**带来新的权限：终端本身就已经给了同一用户完整的 shell，所以文件管理器只是对你已有的权限提供了一个方便的界面。请合理限制该账号的权限范围，并保持应用在认证之后（见 [SECURITY.zh-CN.md](SECURITY.zh-CN.md)）。

| 变量 | 默认值 | 作用 |
|---|---|---|
| `GHOSTDEV_FILES_ENABLED` | `true` | 设为 `false` 可隐藏面板并完全禁用 `/api/fs/*` 端点 |
| `GHOSTDEV_FILES_ROOT` | 应用用户的 home | 管理器被限制到的目录 |
| `GHOSTDEV_FILES_READONLY` | `false` | `true` 允许浏览/下载但阻止所有写入操作（上传、重命名、删除、编辑、新建目录、URL 抓取） |

## API（代理在 `/api/` 下）

| 端点 | 方法 | Body / query |
|---|---|---|
| `/fs/list` | GET | `?path=<rel>` |
| `/fs/read` | GET | `?path=<rel>&dl=1`（强制下载） |
| `/fs/upload` | POST | `{ path, name, b64 }` |
| `/fs/save` | POST | `{ path, content }` |
| `/fs/mkdir` | POST | `{ path, name }` |
| `/fs/rename` | POST | `{ path, to }` |
| `/fs/delete` | POST | `{ path }` |
| `/fs/fetch-url` | POST | `{ path, url }` —— 仅支持 http/https，跟随重定向 |

上传 body 使用 base64 JSON（二进制安全，无需 multipart）。nginx 对 `/api/` 的 `client_max_body_size` 配置为 256m；如需更大的上传，请调大这个值（同时调大 `stats/server.js` 中的 `MAX_UPLOAD`）。URL 下载是流式写入磁盘的，不受此限制。
