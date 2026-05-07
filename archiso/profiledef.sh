#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="torrentos"
iso_label="TORRENTOS_$(date +%Y%m)"
iso_publisher="TorrentOS <https://torrentos.org>"
iso_application="TorrentOS Live/Installer"
iso_version="$(cat /workspace/VERSION 2>/dev/null || cat /torrentos/VERSION 2>/dev/null || date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux'
    'uefi.grub'
)
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="erofs"
airootfs_image_tool_options=('-zlz4hc,12' '-E' 'ztailpacking')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
    ["/root"]="0:0:750"
    ["/root/.automated_script.sh"]="0:0:755"
    ["/root/.gnupg"]="0:0:700"
    # TorrentOS installer scripts (live in airootfs, not in packages)
    ["/usr/local/bin/torrentos-install"]="0:0:755"
    ["/usr/local/bin/torrentos-install-gui"]="0:0:755"
    # NOTE: torrentos-firstboot, torrentos-update-gui, torrentos-screenshot,
    # torrentos-help, and rofi/power-menu.sh are owned by torrentos-* packages
    # and pruned from airootfs before mkarchiso runs — do NOT list them here.
)
