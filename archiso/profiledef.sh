#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="torrentos"
iso_label="TORRENTOS_$(date +%Y%m)"
iso_publisher="TorrentOS <https://torrentos.org>"
iso_application="TorrentOS Live/Installer"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-ia32.grub.esp'
    'uefi-x64.grub.esp'
    'uefi-ia32.grub.eltorito'
    'uefi-x64.grub.eltorito'
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
    ["/usr/local/bin/torrentos-firstboot"]="0:0:755"
    ["/usr/lib/torrentos/devmode"]="0:0:755"
)
