# 反向代理 + SSO

ghostdev 在 localhost 上使用纯 HTTP，并在 `/tty` 路径下代理 websocket。任何反向代理都能用，只要它（a）终结 TLS，（b）转发 websocket 升级，（c）实施认证。

把 `term.example.com` 换成你的域名，并把代理指向 ghostdev 的主机/端口（默认 `127.0.0.1:7680`，或容器发布的地址）。

## Caddy（最省心 —— 自动 TLS）

```caddy
term.example.com {
    # 内置认证（或委托给 forward_auth / SSO 提供方 —— 见下文）。
    basic_auth {
        # 用以下命令生成 bcrypt 哈希：caddy hash-password
        ghost $2a$14$......your-bcrypt-hash......
    }
    reverse_proxy 127.0.0.1:7680
}
```

Caddy 会自动转发 websocket，所以 `/tty` 直接可用。

## nginx

```nginx
server {
    listen 443 ssl http2;
    server_name term.example.com;
    ssl_certificate     /etc/letsencrypt/live/term.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/term.example.com/privkey.pem;

    # 最低标准：HTTP 基础认证（htpasswd）。优先使用下文的 forward-auth/SSO。
    auth_basic           "ghostdev";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:7680;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;     # /tty 需要 websocket
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
}
```

## SSO（Authentik / Authelia / oauth2-proxy / Cloudflare Access）

要在 ghostdev 前放一个统一的身份提供方，使用 **forward-auth**：代理向 IdP 发起认证子请求，只有在成功时才代理到 ghostdev。具体代码片段取决于 IdP，但整体流程都是：

```
浏览器 → 反向代理
   └─ 认证子请求 → IdP   （没有会话时返回 401 / 重定向到登录；已登录返回 200/204）
        └─ 成功 → 代理到 ghostdev (127.0.0.1:7680)
```

- **Authentik / Authelia：** 把它们的 forward-auth 片段加到代理主机配置里。确保认证请求自身的 location 豁免认证（不要把 IdP 自己的回调路径也加门禁），否则会陷入重定向循环。
- **Cloudflare Access / Tunnel：** 把 ghostdev 放在 Tunnel 后面，并要求 Access 策略生效。完全不需要入站端口。
- **oauth2-proxy：** 让它跑在前面，它建立好会话之后再 `reverse_proxy` 到 ghostdev。

因为所有内容（包括 `/tty` websocket）都在同一个 origin 下，所以门禁根路径就覆盖了整个应用。
