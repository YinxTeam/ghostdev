# Orca headless server

The image bundles the **server-only** build of [Orca](https://github.com/stablyai/orca). On Linux the CLI is called `orca-ide` (because `/usr/bin/orca` belongs to GNOME's screen reader). The container runs `orca-ide serve` by default; after you log in to your Orca account and pair a device, you can use it from your phone or any other device on **any network** through **Orca Relay** — **no published ports and no public IP needed**.

> Upstream marks Remote Orca Servers as beta. The server-only build has no browser panes or dictation.

## One-time setup

After the container is up, run two interactive steps (hence `-it`):

```bash
# 1. Log in to your Orca account: prints a link; sign in in any browser and paste the code back
docker exec -it ghostdev orca-ide auth login

# 2. Generate the mobile pairing QR/link (via Orca Relay)
docker exec -it ghostdev orca-ide pair --mobile --relay
```

Then scan the QR or paste the `orca://pair?...` link in Orca on your phone. The server must be running **before** you log in (it starts with the container by default).

> The pairing link is a password. The server runs in supervised mode and does not print it to `docker logs`; only generate it with the command above when you need it.

Handy commands:

```bash
docker exec -it ghostdev orca-ide auth status   # login state
docker exec -it ghostdev orca-ide status        # server state
docker exec -it ghostdev orca-ide pair --mobile --relay --rotate   # replace an unused pairing offer
```

> `orca-ide --help` is the source of truth. Upstream docs: <https://github.com/stablyai/orca/tree/main/docs/site/content/docs>.

## Connecting other computers (desktop Orca)

**Phones go through Relay, but desktop Orca can't** (`orca-ide pair --relay` only works with `--mobile`; otherwise it errors with `--relay applies only with --mobile`). Other computers must reach the container's port 6768 directly. There are three ways — **never expose 6768 to the public internet directly**:

First generate a desktop pairing link in the container (no `--mobile`); `--address` is where the client will actually dial:

```bash
docker exec -it ghostdev orca-ide pair --address <address[:port] the client can reach>
```

Then in Orca on that computer: **Settings → Remote Orca Servers → Add Server** and paste the `orca://pair?...` link. Or from the CLI:

```bash
orca-ide environment add --name ghostdev --pairing-code 'orca://pair?code=...'
```

### Option 1: SSH tunnel (no extra components, recommended)

Reuses ghostdev's built-in key-only SSH (set `GHOSTDEV_SSH_PUBKEY` in `.env`; host port 2222 by default).

```bash
# On the computer you want to connect from: forward local 16768 to the container's 6768; keep it open
ssh -N -L 16768:127.0.0.1:6768 -p 2222 ghost@<host>

# In the container: generate a link that points the client at the forwarded local port
docker exec -it ghostdev orca-ide pair --address 127.0.0.1:16768
```

16768 instead of 6768 avoids clashing with that computer's own Orca. Each computer opens its own tunnel and gets its own link.

### Option 2: Tailscale / WireGuard

Put the host and that computer on the same tailnet, and publish the port **only on the Tailscale IP** in `docker-compose.yml`:

```yaml
      - "100.x.y.z:6768:6768"   # the host's Tailscale IP
```

```bash
docker exec -it ghostdev orca-ide pair --address 100.x.y.z
```

Inside the container Orca accepts localhost, LAN and Tailscale ranges by default and refuses public addresses.

### Option 3: Reverse proxy with TLS and auth

Proxy `wss://orca.example.com` to the container's 6768 (WebSocket required) with authentication in front, see [reverse-proxy.md](reverse-proxy.md):

```bash
docker exec -it ghostdev orca-ide pair --address wss://orca.example.com
```

### Notes

- Each paired device gets its **own revocable token**; other devices are unaffected. The link is a password — don't share one link between people.
- After a restart an unused link can't be printed again; a new one is made and the old one keeps working. `--rotate` replaces an unused offer.
- Plain `pair` (no `--address`) prints the container-internal address (e.g. `172.17.0.2`), which only works on the host itself. Always pass `--address` for remote devices.
- Options 1 and 2 follow the upstream docs; Option 3 hasn't been run end to end here.

## Networking

- The container does not publish Orca's port (default 6768).
- Relay only needs **outbound** TCP 443 to `login.onorca.dev`, `relay.onorca.dev` and `*.relay.onorca.dev`.
- Upstream advises against exposing 6768 to the public internet. For other computers see "Connecting other computers" above.

## Configuration

| Variable | Default | What it does |
|---|---|---|
| `GHOSTDEV_ORCA_ENABLE` | `true` | `false` = don't start Orca |
| `GHOSTDEV_WORKSPACE` | `/home/ghost/workspace` | Orca project root; created automatically, lives in the persisted volume |

Agents Orca spawns (e.g. Claude Code) run as `ghost` and reuse the login stored in `~/.claude`.

Build args:

```bash
docker compose build --build-arg INSTALL_ORCA=false          # don't install Orca
docker compose build --build-arg ORCA_VERSION=v1.4.266       # pin a version (default: latest)
```

The archive is verified against `orca-server-sha256sums.txt` from the same release.

## Persistence

Orca's state (pairing keys, paired devices, login) lives in `~/.config/orca`, i.e. the `ghostdev-home` volume (`/home/ghost`), so you don't have to log in or pair again after restarts or image upgrades.

> Don't clone this volume (or an image carrying it) into another instance: clones share the pairing identity. Run `orca-ide serve reset-identity`, or set a distinct `ORCA_INSTANCE_ID` per instance.

## Upgrading

The server-only build has no `update` command, and paired clients can't update it. Two options:

- Auto-update: Claude Code, cc-switch and Orca are updated every 24h by default (`GHOSTDEV_AUTOUPDATE=false` to disable, `GHOSTDEV_AUTOUPDATE_HOURS` to change the period; Orca restarts for a few seconds when a new version lands).
- Manual update now, no rebuild, pairing kept (omit `orca` to update everything):

  ```bash
  docker exec -it ghostdev ghost-update orca            # latest
  docker exec -it ghostdev ghost-update orca v1.4.270   # specific version
  ```

  It verifies the sha256, replaces `/opt/orca-server`, and stops Orca; the entrypoint restarts it within ~5s. A rebuilt image reverts to the version baked into the image.
- Rebuild the image (defaults to the latest release; use `--no-cache` to avoid a stale layer) and restart the container.

## Security

See [SECURITY.md](SECURITY.md). In short: Relay traffic goes through Orca's relay service; a paired device gets a shell as `ghost`; treat the pairing link like a password. Set `GHOSTDEV_ORCA_ENABLE=false` if you don't need it.

## Troubleshooting

- An Orca crash doesn't affect the web terminal; the entrypoint restarts it every 5 s. Logs: `docker logs ghostdev`.
- `auth login` fails: make sure the server is running (`docker exec ghostdev pgrep -fa orca`) and the container can reach `login.onorca.dev:443`.
- `orcad_identity_mismatch: the server on remote port 6768 is not this host's Orca server`: whatever answers on the port the client dialed is not the server it was paired with. Common causes:
  1. The tunnel's local port clashes with that computer's own Orca (also 6768 by default), so the client reached its local Orca. Use a free port such as 16768 for the tunnel and the same port in `--address`; on Windows check with `netstat -ano | findstr 6768`.
  2. The tunnel isn't up (`ssh` exited, port in use), or the `--address` port doesn't match the tunnel port.
  3. The data volume was recreated/reset so the server identity changed, while the client still holds the old pairing. Delete the old Remote Server on the client, then `pair` again and re-add it.
  4. You used the desktop app's built-in "SSH hosts" feature (Orca deploys and manages its own server over SSH). It clashes with the Orca already running in the container. Don't use it with ghostdev; connect manually through the SSH tunnel above.
     Such servers can't be removed from Remote Orca Servers (error `Orca runs this server on an SSH host for you`). Remove them in Settings > Orca on your SSH hosts, or run `orca environment stop --environment <name> --yes` (stops the server the desktop deployed on the host); if the host is gone, use `orca environment forget --environment <name> --yes` (unlinks locally without contacting the host).
  5. SSH went to something other than the ghostdev container (e.g. the host's port 22 instead of the mapped 2222).
- Known issue: `--mobile-pairing` with a narrow `--bind` is refused (upstream issue #39728).
