# cc-switch CLI

The image bundles [cc-switch-cli](https://github.com/SaladDay/cc-switch-cli), a terminal tool for
switching Claude Code **provider configurations** (API endpoint, key, model) without hand-editing
config files. It's handy when you use several providers or relay services and want to flip between
them from the browser terminal.

## Usage

Open a tab in ghostdev and run:

```bash
cc-switch            # start the tool (interactive)
cc-switch --help     # list all commands and options
cc-switch --version  # print the installed version
```

Add your providers, pick one, then start (or restart) `claude` so it picks up the new settings.

> The exact subcommands depend on the installed release — `cc-switch --help` is the source of truth.
> Upstream docs: <https://github.com/SaladDay/cc-switch-cli>.

## Persistence

cc-switch keeps its data and writes Claude Code's settings under the user's home directory, which is
the `ghostdev-home` volume (`/home/ghost`). Provider configs and the active selection therefore
survive container restarts and image upgrades.

> Provider entries contain API keys. They live in the volume, not in the image or `.env` — don't
> commit or share the volume contents.

## Display

The image sets `LANG=C.UTF-8`, so cc-switch's Chinese UI renders correctly inside tmux. If you see
`_` in place of CJK characters on a custom setup, make sure a UTF-8 locale is set.

## Build option

The binary is downloaded from the upstream GitHub release at build time (amd64 and arm64). To build
without it:

```bash
docker compose build --build-arg INSTALL_CC_SWITCH=false
```
