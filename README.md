<div align="center">

```
  ████████╗ ██████╗ ██████╗ ██████╗ ███████╗███╗   ██╗████████╗ ██████╗ ███████╗
     ██╔══╝██╔═══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔════╝
     ██║   ██║   ██║██████╔╝██████╔╝█████╗  ██╔██╗ ██║   ██║   ██║   ██║███████╗
     ██║   ██║   ██║██╔══██╗██╔══██╗██╔══╝  ██║╚██╗██║   ██║   ██║   ██║╚════██║
     ██║   ╚██████╔╝██║  ██║██║  ██║███████╗██║ ╚████║   ██║   ╚██████╔╝███████║
     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚══════╝
```

**An independent operating system. Built from scratch.**

[![Build](https://img.shields.io/github/actions/workflow/status/rupertjwakefield2-dot/torrentos/build-iso.yml?branch=main&style=flat-square&color=1E6FFF&label=build)](https://github.com/rupertjwakefield2-dot/torrentos/actions)
[![License](https://img.shields.io/badge/license-GPL--3.0-1E6FFF?style=flat-square)](LICENSE)

</div>

---

## Download

<div align="center">

### [⬇ Download TorrentOS](https://github.com/rupertjwakefield2-dot/torrentos/actions)

*Download the latest ISO from the Actions tab → most recent build → Artifacts*

</div>

1. Download the `.iso` from the link above
2. Flash to USB with [Rufus](https://rufus.ie) *(Windows)* or [Balena Etcher](https://etcher.balena.io)
3. Boot from USB

> Minimum: any x86 PC · 512 MB RAM · 1 GB storage

---

## What is TorrentOS?

TorrentOS is an independent operating system built from the ground up. The kernel, drivers, display system, keyboard input, and shell are all original TorrentOS code — written from scratch, with no external OS underneath.

The only external component is the **bootloader** (GRUB) — its sole job is to load the TorrentOS kernel from disk and hand over control. From that point on, everything is TorrentOS.

---

## Current state — v0.1 kernel

| Component | Status |
|---|---|
| Boot | ✅ Boots from USB via GRUB |
| Display | ✅ Full VGA text driver (original code) |
| Keyboard | ✅ PS/2 keyboard driver (original code) |
| Shell | ✅ Command shell with built-in commands |
| Memory | 🔄 Basic — full memory manager coming |
| Filesystem | 🔄 Planned |
| GUI | 🔄 Planned |
| Networking | 🔄 Planned |

**Shell commands:** `help` · `version` · `about` · `clear` · `reboot` · `halt`

---

## Build from source

```bash
git clone https://github.com/rupertjwakefield2-dot/torrentos
cd torrentos
bash build.sh
```

Requires: `gcc` · `gcc-multilib` · `grub-pc-bin` · `xorriso`

---

## Roadmap

- [ ] Memory manager (paging, heap allocation)
- [ ] Filesystem (read/write files)  
- [ ] Process management (run multiple programs)
- [ ] Graphics mode (pixel display)
- [ ] Network stack
- [ ] TorrentOS GUI desktop

---

## License

GPL-3.0 — TorrentOS is fully open source.
