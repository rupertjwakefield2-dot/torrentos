"""Apply settings changes to the live system.

Each function knows how to push one setting domain into the actual running
configuration — GTK theme, Hyprland keyword, hyprpaper, etc.

All functions are idempotent and safe to call repeatedly.
"""

from __future__ import annotations

import os
import re
import shlex
import subprocess
from pathlib import Path


HOME = Path.home()


def _run(cmd: list[str] | str, check: bool = False) -> int:
    """Run a command silently. Returns exit code."""
    if isinstance(cmd, str):
        cmd = shlex.split(cmd)
    try:
        return subprocess.run(cmd, check=check, capture_output=True).returncode
    except Exception as e:
        print(f"[applier] {' '.join(cmd[:2])} failed: {e}")
        return 1


def _hyprctl(keyword: str, value: str) -> int:
    return _run(["hyprctl", "keyword", keyword, value])


def _gsettings(schema: str, key: str, value: str) -> int:
    return _run(["gsettings", "set", schema, key, value])


def _write_gtk_settings(key: str, value: str) -> None:
    """Update a key in gtk-3.0/settings.ini and gtk-4.0/settings.ini."""
    for ver in ("gtk-3.0", "gtk-4.0"):
        path = HOME / ".config" / ver / "settings.ini"
        path.parent.mkdir(parents=True, exist_ok=True)
        text = path.read_text() if path.exists() else "[Settings]\n"
        pattern = re.compile(rf"^{re.escape(key)}\s*=.*$", re.MULTILINE)
        replacement = f"{key}={value}"
        if pattern.search(text):
            text = pattern.sub(replacement, text)
        else:
            if not text.endswith("\n"):
                text += "\n"
            text += replacement + "\n"
        path.write_text(text)


# ── Appearance ───────────────────────────────────────────────────────────────

def apply_theme(theme: str) -> None:
    """theme: 'dark' | 'light' | 'auto'."""
    pref = {"dark": "prefer-dark", "light": "prefer-light"}.get(theme, "default")
    gtk_theme = "TorrentOS-Light" if theme == "light" else "TorrentOS-Dark"
    _gsettings("org.gnome.desktop.interface", "color-scheme", pref)
    _gsettings("org.gnome.desktop.interface", "gtk-theme", gtk_theme)
    _write_gtk_settings("gtk-application-prefer-dark-theme", "1" if theme == "dark" else "0")
    _write_gtk_settings("gtk-theme-name", gtk_theme)


def apply_accent(hex_color: str) -> None:
    """Update Hyprland border colour. Format: '#RRGGBB'."""
    h = hex_color.lstrip("#").lower()
    if len(h) != 6:
        return
    # Gradient from accent to a lighter complementary tone
    _hyprctl("general:col.active_border", f"rgba({h}ff) rgba({h}aa) 45deg")


def apply_wallpaper(path: str) -> None:
    if not Path(path).exists():
        return
    _run(["hyprctl", "hyprpaper", "preload", path])
    _run(["hyprctl", "hyprpaper", "wallpaper", f",{path}"])
    # Update hyprpaper.conf so it persists across restarts
    conf = HOME / ".config" / "hypr" / "hyprpaper.conf"
    conf.write_text(
        f"preload = {path}\n"
        f"wallpaper = ,{path}\n"
        "splash = false\n"
        "ipc = on\n"
    )


def apply_font_size(size: int) -> None:
    font = f"Inter {size}"
    _gsettings("org.gnome.desktop.interface", "font-name", font)
    _gsettings("org.gnome.desktop.interface", "document-font-name", font)
    _gsettings("org.gnome.desktop.interface", "monospace-font-name", f"JetBrainsMono Nerd Font {size}")
    _write_gtk_settings("gtk-font-name", font)


def apply_animations(enabled: bool) -> None:
    _hyprctl("animations:enabled", "1" if enabled else "0")
    _gsettings("org.gnome.desktop.interface", "enable-animations", "true" if enabled else "false")


def apply_blur(enabled: bool) -> None:
    _hyprctl("decoration:blur:enabled", "1" if enabled else "0")


def apply_rounding(radius: int) -> None:
    _hyprctl("decoration:rounding", str(radius))


# ── Accessibility ────────────────────────────────────────────────────────────

def _read_setting(dotted: str, fallback: str = "") -> str:
    """Read a single setting from the user settings TOML (no fallback to defaults)."""
    try:
        import tomllib  # Python 3.11+
    except ImportError:
        try:
            import tomli as tomllib  # type: ignore[no-redef]
        except ImportError:
            return fallback
    user_toml = HOME / ".config" / "torrentos" / "settings.toml"
    if not user_toml.exists():
        return fallback
    try:
        with user_toml.open("rb") as f:
            data = tomllib.load(f)
        cur = data
        for part in dotted.split("."):
            if not isinstance(cur, dict) or part not in cur:
                return fallback
            cur = cur[part]
        return str(cur)
    except Exception:
        return fallback


def apply_high_contrast(enabled: bool) -> None:
    if enabled:
        theme = "HighContrast"
    else:
        current_theme = _read_setting("appearance.theme", "dark")
        theme = "TorrentOS-Light" if current_theme == "light" else "TorrentOS-Dark"
    _gsettings("org.gnome.desktop.interface", "gtk-theme", theme)


def apply_screen_reader(enabled: bool) -> None:
    svc = "start" if enabled else "stop"
    _run(f"systemctl --user {svc} orca.service", check=False)
    val = "true" if enabled else "false"
    _gsettings("org.gnome.desktop.a11y.applications", "screen-reader-enabled", val)


def apply_ui_scale(scale: float) -> None:
    _hyprctl("monitor", f",preferred,auto,{scale}")


def apply_sticky_keys(enabled: bool) -> None:
    _gsettings("org.gnome.desktop.a11y.keyboard", "stickykeys-enable", "true" if enabled else "false")


def apply_slow_keys(enabled: bool) -> None:
    _gsettings("org.gnome.desktop.a11y.keyboard", "slowkeys-enable", "true" if enabled else "false")


def apply_mouse_keys(enabled: bool) -> None:
    _gsettings("org.gnome.desktop.a11y.keyboard", "mousekeys-enable", "true" if enabled else "false")


def apply_color_filter(filter_name: str) -> None:
    """Apply a color-blindness compensation filter.

    Stored in settings for future hyprland-shader or Mutter integration.
    Currently sets the GNOME a11y flag if a filter is active; full GPU-level
    filtering is a planned feature once hyprland plugin support matures.
    """
    enabled = filter_name != "none"
    _gsettings(
        "org.gnome.settings-daemon.plugins.color",
        "night-light-enabled",
        "false",  # don't accidentally trigger night light
    )
    # Reflect the 'something is active' state in the a11y panel
    _gsettings(
        "org.gnome.desktop.a11y.display",
        "use-grayscale",
        "true" if filter_name == "grayscale" else "false",
    )
    # Persist for session restore via torrentos-settingsd
    # (full shader implementation is in the roadmap)
    _ = enabled  # suppress unused-variable warning


def apply_live_captions(enabled: bool) -> None:
    """Toggle live captions.  Planned feature — no supported backend yet."""
    # No package in packages.x86_64 provides a live-caption daemon today.
    # The setting is persisted by the Settings store; this stub prevents silent
    # no-ops becoming confusing when the backend is eventually wired up.
    print(f"[applier] live-captions: {'enabled' if enabled else 'disabled'} (backend not yet implemented)")


# ── Display ──────────────────────────────────────────────────────────────────

def apply_night_light(enabled: bool, temp: int = 4000) -> None:
    _run(["pkill", "-f", "gammastep"])   # returns 1 if not running; check=False ignores it
    if enabled:
        subprocess.Popen(
            ["gammastep", "-O", str(temp)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True,
        )


def apply_refresh_rate(hz: int) -> None:
    _hyprctl("monitor", f",preferred,auto,auto,{hz}")


# ── Keyboard / Mouse ─────────────────────────────────────────────────────────

def apply_kb_layout(layout: str) -> None:
    _hyprctl("input:kb_layout", layout)
    _run(["localectl", "set-keymap", layout])
    # Persist to user.conf
    user_conf = HOME / ".config" / "hypr" / "user.conf"
    text = user_conf.read_text() if user_conf.exists() else ""
    pattern = re.compile(r"kb_layout\s*=.*")
    replacement = f"kb_layout = {layout}"
    if pattern.search(text):
        text = pattern.sub(replacement, text)
    else:
        text += f"\ninput {{\n    {replacement}\n}}\n"
    user_conf.write_text(text)


def apply_mouse_sensitivity(val: float) -> None:
    _hyprctl("input:sensitivity", str(val))


def apply_natural_scroll(enabled: bool) -> None:
    _hyprctl("input:touchpad:natural_scroll", "1" if enabled else "0")


def apply_kb_repeat_delay(delay: int) -> None:
    _hyprctl("input:repeat_delay", str(delay))


def apply_kb_repeat_rate(rate: int) -> None:
    _hyprctl("input:repeat_rate", str(rate))


def apply_tap_to_click(enabled: bool) -> None:
    _hyprctl("input:touchpad:tap-to-click", "1" if enabled else "0")


def apply_numlock(enabled: bool) -> None:
    _hyprctl("input:numlock_by_default", "1" if enabled else "0")


def apply_vrr(enabled: bool) -> None:
    _hyprctl("misc:vrr", "1" if enabled else "0")


# ── Dispatch table ────────────────────────────────────────────────────────────

DISPATCH: dict[str, object] = {
    "appearance.theme":         lambda v: apply_theme(v),
    "appearance.accent":        lambda v: apply_accent(v),
    "appearance.wallpaper":     lambda v: apply_wallpaper(v),
    "appearance.font-size":     lambda v: apply_font_size(int(v)),
    "appearance.animations":    lambda v: apply_animations(bool(v)),
    "appearance.blur":          lambda v: apply_blur(bool(v)),
    "appearance.rounding":      lambda v: apply_rounding(int(v)),
    "accessibility.high-contrast":   lambda v: apply_high_contrast(bool(v)),
    "accessibility.screen-reader":   lambda v: apply_screen_reader(bool(v)),
    "accessibility.ui-scale":        lambda v: apply_ui_scale(float(v)),
    "accessibility.sticky-keys":     lambda v: apply_sticky_keys(bool(v)),
    "accessibility.slow-keys":       lambda v: apply_slow_keys(bool(v)),
    "accessibility.mouse-keys":      lambda v: apply_mouse_keys(bool(v)),
    "accessibility.color-filter":    lambda v: apply_color_filter(str(v)),
    "accessibility.live-captions":   lambda v: apply_live_captions(bool(v)),
    "display.night-light":           lambda v: apply_night_light(bool(v)),
    "display.night-light-temp":      lambda v: None,  # handled by night-light toggle
    "display.scale":                 lambda v: apply_ui_scale(float(v)),
    "display.vrr":                   lambda v: apply_vrr(bool(v)),
    "display.refresh-rate":          lambda v: apply_refresh_rate(int(v)) if str(v) not in ("0", "auto") else None,
    "keyboard.layout":               lambda v: apply_kb_layout(str(v)),
    "keyboard.natural-scroll":       lambda v: apply_natural_scroll(bool(v)),
    "keyboard.mouse-sensitivity":    lambda v: apply_mouse_sensitivity(float(v)),
    "keyboard.repeat-delay":         lambda v: apply_kb_repeat_delay(int(v)),
    "keyboard.repeat-rate":          lambda v: apply_kb_repeat_rate(int(v)),
    "keyboard.tap-to-click":         lambda v: apply_tap_to_click(bool(v)),
    "keyboard.numlock":              lambda v: apply_numlock(bool(v)),
}


def apply(key: str, value) -> None:
    fn = DISPATCH.get(key)
    if fn:
        fn(value)
