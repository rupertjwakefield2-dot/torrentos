# TorrentOS

An Arch-based Linux distribution that aims for macOS aesthetics, Windows-grade
accessibility, and Linux developer power.

## Repo layout

```
torrentos/
├── archiso/                    archiso profile (consumed by mkarchiso)
│   ├── profiledef.sh           ISO metadata + build flags
│   ├── packages.x86_64         packages installed into the live system
│   ├── pacman.conf             pacman config used inside the chroot
│   └── airootfs/               files copied verbatim into the live root
│       ├── etc/skel/           default user dotfiles
│       └── usr/share/torrentos branding & assets
├── packages/                   custom PKGBUILDs hosted in the torrentos repo
│   ├── torrentos-base/         meta-package (deps + branding)
│   ├── torrentos-theme/        GTK/Qt/icon/cursor theme bundle
│   ├── torrentos-hyprland-config/  default Hyprland + Waybar config
│   └── torrentos-first-boot/   welcome wizard
├── scripts/                    build helpers
│   ├── build-iso.sh            wraps mkarchiso
│   ├── build-pkgs.sh           builds all PKGBUILDs into a local repo
│   └── repo-add.sh             signs + indexes packages for repo.torrentos.org
└── docs/
    └── BUILDING.md             how to build, on what host, with what creds
```

## Quick start

You need an **Arch Linux host** (WSL2 with archlinux works, or a VM, or bare
metal). Building from Windows directly is not supported — `mkarchiso` requires
a Linux kernel + loop devices.

```bash
# from inside Arch:
sudo pacman -S --needed archiso base-devel git
cd torrentos
./scripts/build-pkgs.sh         # builds the custom packages into ./repo/
./scripts/build-iso.sh          # produces ./out/torrentos-<date>-x86_64.iso
```

See [docs/BUILDING.md](docs/BUILDING.md) for full instructions.

## Status

v0 scaffold. Boots to a Hyprland session with TorrentOS branding. Settings
daemon, first-boot wizard, and Dev Mode installer are stubbed but not yet
implemented.

## License

GPL-3.0 for distro-specific code. Upstream packages keep their original
licenses.
