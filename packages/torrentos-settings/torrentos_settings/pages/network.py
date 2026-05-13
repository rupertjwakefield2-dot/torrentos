"""Network settings page — WiFi, hostname, proxy."""

from __future__ import annotations

import re
import subprocess
import threading

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk, GLib  # noqa: E402

from ..settings import Settings


def _nmcli(*args: str) -> str:
    try:
        return subprocess.check_output(
            ["nmcli", *args], text=True, timeout=8
        ).strip()
    except Exception:
        return ""


def _get_hostname() -> str:
    try:
        return subprocess.check_output(["hostname"], text=True).strip()
    except Exception:
        return "torrentos"


def _get_wifi_networks() -> list[dict]:
    """Return list of scanned wifi networks."""
    try:
        out = subprocess.check_output(
            ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY,IN-USE",
             "dev", "wifi", "list"],
            text=True, timeout=8,
        )
        nets = []
        seen = set()
        # nmcli -t uses ':' as delimiter and escapes literal ':' in values as '\:'
        # Split on unescaped colons only, then unescape.
        _split_re = re.compile(r'(?<!\\):')
        for line in out.splitlines():
            parts = _split_re.split(line, maxsplit=3)
            if len(parts) >= 4:
                ssid = parts[0].replace(r'\:', ':').strip()
                if not ssid or ssid in seen:
                    continue
                seen.add(ssid)
                try:
                    signal = int(parts[1])
                except ValueError:
                    signal = 0
                security = parts[2].replace(r'\:', ':').strip()
                in_use = parts[3].strip() == "*"
                nets.append({
                    "ssid": ssid,
                    "signal": signal,
                    "security": security,
                    "in_use": in_use,
                })
        nets.sort(key=lambda n: (-n["in_use"], -n["signal"]))
        return nets[:20]
    except Exception:
        return []


def _signal_icon(pct: int) -> str:
    if pct >= 80: return "network-wireless-signal-excellent-symbolic"
    if pct >= 60: return "network-wireless-signal-good-symbolic"
    if pct >= 40: return "network-wireless-signal-ok-symbolic"
    if pct >= 20: return "network-wireless-signal-weak-symbolic"
    return "network-wireless-signal-none-symbolic"


class NetworkPage(Adw.PreferencesPage):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.set_name("network")
        self.set_title("Network")
        self.set_icon_name("network-wireless-symbolic")
        self.settings = settings

        # ── WiFi group ───────────────────────────────────────────────────────
        wifi_group = Adw.PreferencesGroup()
        wifi_group.set_title("WiFi")

        # Rescan header button
        rescan_btn = Gtk.Button(label="Scan")
        rescan_btn.add_css_class("flat")
        rescan_btn.set_valign(Gtk.Align.CENTER)
        rescan_btn.connect("clicked", self._on_rescan)
        wifi_group.set_header_suffix(rescan_btn)

        wifi_group.set_description("Click a network to connect via nmtui")
        self.add(wifi_group)
        self._wifi_group = wifi_group
        self._wifi_rows: list[Adw.ActionRow] = []

        # Load networks on a background thread so nmcli doesn't block the UI
        threading.Thread(target=self._load_wifi_thread, daemon=True).start()

        # ── Advanced / NM group (always below WiFi rows) ─────────────────────
        nm_group = Adw.PreferencesGroup()
        self.add(nm_group)

        nm_row = Adw.ActionRow()
        nm_row.set_title("Advanced network settings")
        nm_row.set_subtitle("Open Network Manager for VPN, static IP, proxy…")
        nm_row.set_activatable(True)
        nm_row.set_icon_name("preferences-system-network-symbolic")
        nm_row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
        nm_row.connect("activated", lambda _: subprocess.Popen(["nm-connection-editor"]))
        nm_group.add(nm_row)

        # ── Hostname group ───────────────────────────────────────────────────
        host_group = Adw.PreferencesGroup()
        host_group.set_title("Device identity")
        self.add(host_group)

        self._hostname_row = Adw.EntryRow()
        self._hostname_row.set_title("Hostname")
        self._hostname_row.set_text(_get_hostname())
        self._hostname_row.connect("apply", self._on_hostname_apply)
        host_group.add(self._hostname_row)

        # ── Proxy group ──────────────────────────────────────────────────────
        proxy_group = Adw.PreferencesGroup()
        proxy_group.set_title("Proxy")
        proxy_group.set_description("HTTP/HTTPS proxy for terminal and most applications")
        self.add(proxy_group)

        proxy_switch = Adw.SwitchRow()
        proxy_switch.set_title("Use proxy")
        proxy_switch.set_active(bool(settings.get("network.proxy-enabled", False)))
        proxy_switch.connect("notify::active", self._on_proxy_toggled)
        proxy_group.add(proxy_switch)

        self._proxy_row = Adw.EntryRow()
        self._proxy_row.set_title("Proxy address")
        self._proxy_row.set_text(settings.get("network.proxy", ""))
        self._proxy_row.set_show_apply_button(True)
        self._proxy_row.connect("apply", self._on_proxy_apply)
        self._proxy_row.set_sensitive(bool(settings.get("network.proxy-enabled", False)))
        proxy_group.add(self._proxy_row)
        self._proxy_switch = proxy_switch

    # ── WiFi loading ──────────────────────────────────────────────────────────

    def _load_wifi_thread(self):
        """Fetch WiFi networks off the UI thread, then post the update."""
        networks = _get_wifi_networks()
        GLib.idle_add(self._populate_wifi, networks)

    def _populate_wifi(self, networks: list[dict]):
        """Called on the UI thread to rebuild the WiFi rows."""
        for row in self._wifi_rows:
            self._wifi_group.remove(row)
        self._wifi_rows.clear()

        if not networks:
            row = Adw.ActionRow()
            row.set_title("No networks found")
            row.set_subtitle("Make sure WiFi is enabled and click Scan")
            self._wifi_group.add(row)
            self._wifi_rows.append(row)
            return

        for net in networks:
            row = Adw.ActionRow()
            ssid = net["ssid"]
            row.set_title(ssid)
            row.set_activatable(True)

            # Signal icon
            sig_icon = Gtk.Image.new_from_icon_name(_signal_icon(net["signal"]))
            sig_icon.set_pixel_size(16)
            row.add_prefix(sig_icon)

            parts = []
            if net["in_use"]:
                parts.append("Connected")
                row.add_css_class("success")
            if net["security"]:
                parts.append(net["security"])
            parts.append(f"{net['signal']}%")
            row.set_subtitle("  ·  ".join(parts))

            if not net["in_use"]:
                row.add_suffix(Gtk.Image.new_from_icon_name("go-next-symbolic"))
                row.connect("activated", self._on_wifi_row_activated, ssid)

            self._wifi_group.add(row)
            self._wifi_rows.append(row)

    def _on_rescan(self, _btn):
        subprocess.Popen(["nmcli", "dev", "wifi", "rescan"])
        GLib.timeout_add(2000, lambda: threading.Thread(
            target=self._load_wifi_thread, daemon=True).start() or GLib.SOURCE_REMOVE
        )

    def _on_wifi_row_activated(self, _row, ssid: str):
        # Open nmtui in ghostty for connecting — pass ssid as a separate arg,
        # not interpolated into a shell string, to handle SSIDs with quotes/spaces.
        for term_args in (
            ["ghostty", "--title=Connect to WiFi", "-e", "nmtui", "connect", ssid],
            ["foot",    "--title=Connect to WiFi", "-e", "nmtui", "connect", ssid],
            ["xterm",   "-title", "Connect to WiFi", "-e", "nmtui", "connect", ssid],
        ):
            try:
                subprocess.Popen(term_args)
                return
            except FileNotFoundError:
                continue
        subprocess.Popen(["nmtui", "connect", ssid])

    # ── Hostname ──────────────────────────────────────────────────────────────

    def _on_hostname_apply(self, _row):
        name = self._hostname_row.get_text().strip()
        if not name:
            return
        try:
            subprocess.run(["hostnamectl", "set-hostname", name], check=True)
            self.settings.set("network.hostname", name)
        except Exception as e:
            print(f"[network] hostname change failed: {e}")

    # ── Proxy ─────────────────────────────────────────────────────────────────

    def _on_proxy_toggled(self, row: Adw.SwitchRow, _pspec):
        v = row.get_active()
        self.settings.set("network.proxy-enabled", v)
        self._proxy_row.set_sensitive(v)
        if not v:
            self._clear_proxy()

    def _on_proxy_apply(self, _row):
        proxy = self._proxy_row.get_text().strip()
        self.settings.set("network.proxy", proxy)
        if proxy and self._proxy_switch.get_active():
            self._set_proxy(proxy)

    def _set_proxy(self, proxy: str):
        try:
            subprocess.run(["gsettings", "set", "org.gnome.system.proxy", "mode", "manual"])
            subprocess.run(["gsettings", "set", "org.gnome.system.proxy.http", "host", proxy])
        except Exception:
            pass

    def _clear_proxy(self):
        try:
            subprocess.run(["gsettings", "set", "org.gnome.system.proxy", "mode", "none"])
        except Exception:
            pass
