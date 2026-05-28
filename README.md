<div align="center">

```
  ████████╗ ██████╗ ██████╗ ██████╗ ███████╗███╗   ██╗████████╗ ██████╗ ███████╗
     ██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔════╝
     ██║   ██║   ██║██████╔╝██████╔╝█████╗  ██╔██╗ ██║   ██║   ██║   ██║███████╗
     ██║   ██║   ██║██╔══██╗██╔══██╗██╔══╝  ██║╚██╗██║   ██║   ██║   ██║╚════██║
     ██║   ╚██████╔╝██║  ██║██║  ██║███████╗██║ ╚████║   ██║   ╚██████╔╝███████║
     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚══════╝
```

**A private, fast, and beautiful desktop operating system.**

[![Latest Release](https://img.shields.io/github/v/release/rupertjwakefield2-dot/torrentos?label=latest&color=1E6FFF&style=flat-square)](https://github.com/rupertjwakefield2-dot/torrentos/releases/latest)
[![Build](https://img.shields.io/github/actions/workflow/status/rupertjwakefield2-dot/torrentos/build.yml?branch=main&style=flat-square&color=1E6FFF)](https://github.com/rupertjwakefield2-dot/torrentos/actions)
[![License](https://img.shields.io/badge/license-GPL--3.0-1E6FFF?style=flat-square)](LICENSE)

</div>

---

## Download

<div align="center">

### [⬇ Download TorrentOS v0.5 — Riptide](https://github.com/rupertjwakefield2-dot/torrentos/releases/latest)

</div>

1. Download the `.iso` from the link above
2. Flash to a USB drive with [Rufus](https://rufus.ie) *(Windows)* or [Balena Etcher](https://etcher.balena.io) *(Mac/Windows/Linux)*
3. Boot from USB — run `sudo torrentos-install` to install to disk

> Minimum: 4 GB RAM · 20 GB storage · x86_64 processor

---

## What's included

| | |
|---|---|
| **Desktop** | Hyprland compositor · macOS-feel glass dock · Waybar status bar · notification centre |
| **Browser** | Torrent Browser — built-in private browser with DuckDuckGo (independent engine, not Chrome or Firefox) |
| **Terminal** | Ghostty · JetBrains Mono Nerd Font · starship prompt · full zsh environment |
| **Installer** | Guided setup wizard — username, password, WiFi, timezone |
| **Settings** | GTK4 settings app — appearance, display, keyboard, network, accessibility |
| **Privacy** | 10-attempt login lockout · DuckDuckGo default · no telemetry |
| **Gaming** | GameMode · MangoHud · Flatpak + Flathub |
| **Dev tools** | Neovim · Helix · Docker · git · ripgrep · fzf · tmux · btop |
| **Accessibility** | Orca screen reader · high-contrast · colour filters · espeak |

---

## Keyboard shortcuts

| Shortcut | Action |
|----------|--------|
| `Super + Space` | App launcher |
| `Super + Return` | Terminal |
| `Super + B` | Torrent Browser |
| `Super + E` | File manager |
| `Super + ,` | Settings |
| `Super + L` | Lock screen |
| `Super + Q` | Close window |
| `Super + Shift + S` | Screenshot |
| `Super + Ctrl + Q` | Power menu |
| `Super + 1–9` | Switch workspace |

---

## Build from source

```bash
git clone https://github.com/rupertjwakefield2-dot/torrentos
cd torrentos
./scripts/build-pkgs.sh   # build TorrentOS packages
./scripts/build-aur.sh    # build community packages
./scripts/build-iso.sh    # build the final ISO
```

The ISO is written to `./out/torrentos-<version>-x86_64.iso`.

CI builds run automatically on every push — pre-built ISOs are always available on the [Releases page](https://github.com/rupertjwakefield2-dot/torrentos/releases).

---

## Status

**v0.5 — Riptide** · Active development. Boots to a polished desktop with first-boot wizard, GTK4 settings app, Torrent Browser, screenshot tool, and system updater.

---

## License

GPL-3.0 for TorrentOS-specific code. Bundled packages retain their original licences.
