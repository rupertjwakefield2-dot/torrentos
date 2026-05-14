"""About — version, branding, system info, credits."""

from __future__ import annotations

import platform
import subprocess
import threading
from pathlib import Path

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, GLib, Gtk  # noqa: E402

from .. import __version__
from ..settings import Settings


VERSION_FILE = Path("/etc/torrentos/version")
LOGO_FILE    = Path("/usr/share/torrentos/branding/logo.svg")
GITHUB_BASE  = "https://github.com/rupertjwakefield2-dot/torrentos"


# ── helpers ──────────────────────────────────────────────────────────────────

def _read_version_field(field: str, fallback: str = "?") -> str:
    if not VERSION_FILE.exists():
        return fallback
    for line in VERSION_FILE.read_text().splitlines():
        if line.startswith(f"{field}="):
            return line.split("=", 1)[1].strip().strip('"')
    return fallback


def _run(cmd: list[str], fallback: str = "?") -> str:
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return fallback


def _kernel_version() -> str:
    return platform.release() or _run(["uname", "-r"], "?")


def _hyprland_version() -> str:
    raw = _run(["hyprctl", "version"], "")
    # "Hyprland v0.41.2 ..." → "v0.41.2"
    for part in raw.split():
        if part.startswith("v") and part[1:2].isdigit():
            return part
    return raw.split()[0] if raw else "?"


def _memory_info() -> str:
    """Return 'X GB / Y GB' from /proc/meminfo."""
    try:
        info: dict[str, int] = {}
        for line in Path("/proc/meminfo").read_text().splitlines():
            parts = line.split()
            if parts[0] in ("MemTotal:", "MemAvailable:"):
                info[parts[0]] = int(parts[1])  # kB
        total = info.get("MemTotal:", 0) / (1024 ** 2)
        avail = info.get("MemAvailable:", 0) / (1024 ** 2)
        used  = total - avail
        return f"{used:.1f} GB used / {total:.0f} GB total"
    except Exception:
        return "?"


def _cpu_info() -> str:
    try:
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                name = line.split(":", 1)[1].strip()
                # Shorten a bit: remove "(R)", "(TM)", extra spaces
                for tok in ["(R)", "(TM)", "  "]:
                    name = name.replace(tok, "")
                return name.strip()
    except Exception:
        pass
    return _run(["lscpu", "--value", "Model name"], "?")


# ── page ─────────────────────────────────────────────────────────────────────

class AboutPage(Adw.PreferencesPage):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.settings = settings

        codename = _read_version_field("TORRENTOS_CODENAME", "Riptide")
        version  = _read_version_field("TORRENTOS_VERSION", __version__)

        # ── Hero ─────────────────────────────────────────────────────────────
        hero_group = Adw.PreferencesGroup()
        self.add(hero_group)

        hero = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        hero.set_margin_top(28)
        hero.set_margin_bottom(16)
        hero.set_halign(Gtk.Align.CENTER)

        if LOGO_FILE.exists():
            try:
                pic = Gtk.Picture.new_for_filename(str(LOGO_FILE))
                pic.set_size_request(128, 128)
                pic.set_can_shrink(True)
                hero.append(pic)
            except Exception:
                pass

        title_lbl = Gtk.Label()
        title_lbl.set_markup("<span size='xx-large' weight='bold'>TorrentOS</span>")
        hero.append(title_lbl)

        ver_lbl = Gtk.Label(label=f"Version {version}")
        ver_lbl.add_css_class("title-3")
        hero.append(ver_lbl)

        sub_lbl = Gtk.Label(label=f'"{codename}" · Arch Linux')
        sub_lbl.add_css_class("dim-label")
        hero.append(sub_lbl)

        # "Check for Updates" button
        btn_box = Gtk.Box(spacing=8)
        btn_box.set_halign(Gtk.Align.CENTER)
        btn_box.set_margin_top(8)

        update_btn = Gtk.Button()
        update_btn.add_css_class("suggested-action")
        update_btn.add_css_class("pill")
        # Adw.ButtonContent shows both icon and label correctly in GTK4
        btn_content = Adw.ButtonContent()
        btn_content.set_icon_name("software-update-available-symbolic")
        btn_content.set_label("Check for Updates")
        update_btn.set_child(btn_content)
        update_btn.connect("clicked", self._launch_updater)
        btn_box.append(update_btn)

        hero.append(btn_box)
        hero_group.add(hero)

        # ── Release info ──────────────────────────────────────────────────────
        release_group = Adw.PreferencesGroup()
        release_group.set_title("Release")
        self.add(release_group)

        for label, value in [
            ("Version",      version),
            ("Codename",     codename),
            ("Channel",      _read_version_field("TORRENTOS_CHANNEL", "stable")),
            ("Architecture", platform.machine() or "x86_64"),
            ("Base",         "Arch Linux (rolling)"),
            ("Settings UI",  __version__),
        ]:
            row = Adw.ActionRow()
            row.set_title(label)
            row.set_subtitle(value)
            release_group.add(row)

        # ── System info (loaded async to avoid startup lag) ───────────────────
        sys_group = Adw.PreferencesGroup()
        sys_group.set_title("System")
        self.add(sys_group)

        self._sys_rows: dict[str, Adw.ActionRow] = {}
        for label in ("Kernel", "Desktop", "CPU", "Memory"):
            row = Adw.ActionRow()
            row.set_title(label)
            row.set_subtitle("…")
            sys_group.add(row)
            self._sys_rows[label] = row

        threading.Thread(target=self._load_system_info_thread, daemon=True).start()

        # ── Resources ─────────────────────────────────────────────────────────
        links_group = Adw.PreferencesGroup()
        links_group.set_title("Resources")
        self.add(links_group)

        for label, subtitle, url in [
            ("Website",         "torrentos.org",                        "https://torrentos.org"),
            ("Documentation",   "Setup, customisation & guides",        "https://torrentos.org/docs"),
            ("Source Code",     "GitHub — rupertjwakefield2-dot",       GITHUB_BASE),
            ("Report a Bug",    "Issue tracker on GitHub",              f"{GITHUB_BASE}/issues"),
            ("Releases",        "Download previous releases",           f"{GITHUB_BASE}/releases"),
        ]:
            row = Adw.ActionRow()
            row.set_title(label)
            row.set_subtitle(subtitle)
            row.set_activatable(True)
            icon = Gtk.Image.new_from_icon_name("link-symbolic")
            icon.set_valign(Gtk.Align.CENTER)
            row.add_suffix(icon)
            row.connect("activated", lambda _r, u=url: Gtk.show_uri(None, u, 0))
            links_group.add(row)

        # ── Credits ───────────────────────────────────────────────────────────
        credits_group = Adw.PreferencesGroup()
        credits_group.set_title("Credits")
        self.add(credits_group)

        credits_row = Adw.ActionRow()
        credits_row.set_title("Built with")
        credits_row.set_subtitle(
            "Arch Linux · Hyprland · GTK4 · libadwaita · Ghostty · Waybar · rofi · swaync · nwg-dock"
        )
        credits_group.add(credits_row)

        made_row = Adw.ActionRow()
        made_row.set_title("Made by")
        made_row.set_subtitle("Rupert Wakefield & contributors")
        credits_group.add(made_row)

        licence_row = Adw.ActionRow()
        licence_row.set_title("Licence")
        licence_row.set_subtitle("GNU General Public License v3.0")
        licence_row.set_activatable(True)
        lic_icon = Gtk.Image.new_from_icon_name("link-symbolic")
        lic_icon.set_valign(Gtk.Align.CENTER)
        licence_row.add_suffix(lic_icon)
        licence_row.connect(
            "activated",
            lambda _r: Gtk.show_uri(None, "https://www.gnu.org/licenses/gpl-3.0.html", 0),
        )
        credits_group.add(licence_row)

    # ── helpers ───────────────────────────────────────────────────────────────

    def _load_system_info_thread(self) -> None:
        """Gather system info off the UI thread (hyprctl may take ~100 ms)."""
        info = {
            "Kernel":  _kernel_version(),
            "Desktop": f"Hyprland {_hyprland_version()}",
            "CPU":     _cpu_info(),
            "Memory":  _memory_info(),
        }
        GLib.idle_add(self._populate_system_info, info)

    def _populate_system_info(self, info: dict) -> bool:
        for label, value in info.items():
            self._sys_rows[label].set_subtitle(value)
        return GLib.SOURCE_REMOVE

    def _launch_updater(self, _btn: Gtk.Button) -> None:
        try:
            subprocess.Popen(
                ["torrentos-update-gui"],
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass
