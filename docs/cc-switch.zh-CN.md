# cc-switch CLI

镜像内置了 [cc-switch-cli](https://github.com/SaladDay/cc-switch-cli)，这是一个终端工具，用来切换 Claude Code 的**供应商配置**（API 地址、密钥、模型），无需手动编辑配置文件。当你使用多个供应商或中转服务时，可以直接在浏览器终端里来回切换。

## 使用方法

在 ghostdev 中打开一个标签页，运行：

```bash
cc-switch            # 启动工具（交互式）
cc-switch --help     # 列出所有命令和选项
cc-switch --version  # 查看已安装的版本
```

添加你的供应商，选择其中一个，然后启动（或重启）`claude`，让它读取新的设置。

> 具体子命令取决于所安装的版本 —— 以 `cc-switch --help` 为准。
> 上游文档：<https://github.com/SaladDay/cc-switch-cli>。

## 持久化

cc-switch 的数据以及它写入的 Claude Code 设置都位于用户的 home 目录下，也就是 `ghostdev-home` 卷（`/home/ghost`）。因此供应商配置和当前选择在容器重启、镜像升级后都会保留。

> 供应商条目包含 API 密钥。它们存放在卷里，而不是镜像或 `.env` 中 —— 请勿提交或分享卷里的内容。

## 显示

镜像设置了 `LANG=C.UTF-8`，所以 cc-switch 的中文界面可以在 tmux 中正常显示。如果在自定义环境里看到用 `_` 代替中日韩字符，请确认已设置 UTF-8 locale。

## 构建选项

该二进制在构建时从上游 GitHub Release 下载（支持 amd64 和 arm64）。若要构建不含它的版本：

```bash
docker compose build --build-arg INSTALL_CC_SWITCH=false
```
