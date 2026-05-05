# Auto-launch Hyprland on tty1, with crash-loop protection.
#
# Attempt 1: hardware DRM + hardware GL (real GPU, installed system).
# Attempt 2: hardware DRM + software GL via pixman (QEMU virtio-gpu, VMs).
# Attempt 3: headless/nested fallback (debugging without any display HW).

if [[ -z "$WAYLAND_DISPLAY" && "$XDG_VTNR" == "1" && ! -f /tmp/torrentos-no-autostart ]]; then
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 700 "$XDG_RUNTIME_DIR"

    # Populate root's config from skel on first boot (live ISO runs as root,
    # but Hyprland reads $HOME/.config — skel doesn't auto-copy for root).
    if [[ ! -d "$HOME/.config/hypr" ]]; then
        cp -r /etc/skel/.config "$HOME/.config" 2>/dev/null || true
        cp /etc/skel/.zshrc "$HOME/.zshrc" 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface cursor-size 24 2>/dev/null || true
    fi

    # Auto-set UK keyboard if detected (fixes " showing as @ etc.)
    if localectl 2>/dev/null | grep -qi 'gb\|uk'; then
        export $(localectl 2>/dev/null | grep Keymap || true)
    fi

    # Detect GPU for better error messages
    GPU_INFO=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 || echo "unknown")

    # Detect Nvidia GPU without proprietary driver loaded.
    # nouveau doesn't support RTX 40-series — skip hardware GL for these cards
    # and go straight to software renderer so Hyprland actually starts.
    NVIDIA_NO_DRV=0
    if lspci 2>/dev/null | grep -qi 'nvidia'; then
        if ! lsmod 2>/dev/null | grep -q '^nvidia '; then
            NVIDIA_NO_DRV=1
            echo "Nvidia GPU detected without proprietary driver (live ISO) — using software renderer." \
                > /tmp/hyprland-attempt1.log
        fi
    fi

    # --i-am-really-stupid required when running as root (live ISO boots as root).
    # Attempt 1 — hardware GL (fast path on AMD/Intel real hardware; skipped for Nvidia)
    if [[ $NVIDIA_NO_DRV -eq 0 ]]; then
        Hyprland --i-am-really-stupid 2>/tmp/hyprland-attempt1.log
        rc=$?
    else
        rc=1  # force fallback to software renderer
    fi

    if [[ $rc -ne 0 ]]; then
        echo
        echo "Trying software renderer (pixman)…"
        WLR_NO_HARDWARE_CURSORS=1 \
        WLR_RENDERER=pixman \
        LIBGL_ALWAYS_SOFTWARE=1 \
            Hyprland --i-am-really-stupid 2>/tmp/hyprland-attempt2.log
        rc=$?
    fi

    if [[ $rc -ne 0 ]]; then
        echo
        echo "Hyprland failed with software GL — trying headless (Wayland-nested)…"
        LIBGL_ALWAYS_SOFTWARE=1 \
        WLR_RENDERER=pixman \
        WLR_NO_HARDWARE_CURSORS=1 \
        WLR_BACKENDS=headless \
        WLR_LIBINPUT_NO_DEVICES=1 \
            Hyprland --i-am-really-stupid 2>/tmp/hyprland-attempt3.log
        rc=$?
    fi

    if [[ $rc -ne 0 ]]; then
        touch /tmp/torrentos-no-autostart
        clear
        echo
        echo "  ████████╗ ██████╗ ██████╗ ██████╗ ███████╗███╗   ██╗████████╗ ██████╗ ███████╗"
        echo "     ██║   ██╔═══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║╚══██╔══╝██╔═══██╗██╔════╝"
        echo "     ██║   ██║   ██║██████╔╝██████╔╝█████╗  ██╔██╗ ██║   ██║   ██║   ██║███████╗"
        echo "     ██║   ██║   ██║██╔══██╗██╔══██╗██╔══╝  ██║╚██╗██║   ██║   ██║   ██║╚════██║"
        echo "     ██║   ╚██████╔╝██║  ██║██║  ██║███████╗██║ ╚████║   ██║   ╚██████╔╝███████║"
        echo "     ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝   ╚═╝    ╚═════╝ ╚══════╝"
        echo
        echo "  Desktop (Hyprland) could not start."
        echo "  GPU: $GPU_INFO"
        echo
        echo "  ┌──────────────────────────────────────────────────────────┐"
        echo "  │  You can still use TorrentOS from this terminal:         │"
        echo "  │                                                          │"
        echo "  │  WiFi:         nmtui                                     │"
        echo "  │  Install OS:   torrentos-install                         │"
        echo "  │                                                          │"
        echo "  │  Keyboard:     localectl set-keymap uk   (UK layout)     │"
        echo "  │                localectl set-keymap us   (US layout)     │"
        echo "  │                                                          │"
        echo "  │  See GPU log:  cat /tmp/hyprland-attempt1.log | tail -20 │"
        echo "  │  Retry desktop: rm /tmp/torrentos-no-autostart && exit   │"
        echo "  └──────────────────────────────────────────────────────────┘"
        echo

        # Ensure NetworkManager is running so WiFi works from TTY
        systemctl start NetworkManager 2>/dev/null || true
    fi
fi
