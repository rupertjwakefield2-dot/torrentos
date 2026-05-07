"""Dev Mode — single toggle that triggers torrentos-devmode installer."""

from __future__ import annotations

import os
import shlex
import subprocess
from pathlib import Path

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, GLib, Gtk  # noqa: E402

from ..settings import Settings


DEVMODE_BIN = "/usr/lib/torrentos/devmode"


class DevModePage(Adw.PreferencesPage):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.set_name("dev-mode")
        self.set_title("Dev Mode")
        self.set_icon_name("applications-development-symbolic")
        self.settings = settings

        intro = Adw.PreferencesGroup()
        intro.set_title("Dev Mode")
        intro.set_description(
            "Installs a curated developer toolchain: Rust, Go, Java, Bun, Deno, "
            "VS Code, lazygit, k9s, kubectl, and more."
        )
        self.add(intro)

        status_row = Adw.ActionRow()
        status_row.set_title("Status")
        status_row.set_subtitle(
            "Enabled" if settings.get("dev-mode.enabled", False) else "Not installed"
        )
        intro.add(status_row)
        self._status_row = status_row

        action_row = Adw.ActionRow()
        action_row.set_title("Install developer toolchain")
        action_row.set_subtitle("Runs /usr/lib/torrentos/devmode (idempotent)")
        btn = Gtk.Button(label="Install")
        btn.add_css_class("suggested-action")
        btn.set_valign(Gtk.Align.CENTER)
        btn.connect("clicked", self._on_install_clicked)
        action_row.add_suffix(btn)
        intro.add(action_row)

        # ----- What's included -----
        bundle = Adw.PreferencesGroup()
        bundle.set_title("Included tools")
        self.add(bundle)
        for label, sub in [
            ("Languages",          "rustup · go · jdk-temurin · bun · deno · mise"),
            ("Editors & IDEs",     "VS Code · Cursor · Zed (via Flatpak)"),
            ("Cloud & containers", "Docker · kubectl · helm · k9s · gh · ngrok"),
            ("Git workflow",       "lazygit · lazydocker"),
        ]:
            r = Adw.ActionRow()
            r.set_title(label)
            r.set_subtitle(sub)
            bundle.add(r)

    def _on_install_clicked(self, btn: Gtk.Button) -> None:
        if not Path(DEVMODE_BIN).exists():
            self._status_row.set_subtitle(f"Error: {DEVMODE_BIN} not found")
            return

        btn.set_sensitive(False)
        btn.set_label("Installing…")
        self._status_row.set_subtitle("Installing — see terminal for progress")

        # Open in a terminal so the user sees the long pacman output
        term = "ghostty"
        try:
            subprocess.Popen(
                [term, "-e", "bash", "-c", f"{DEVMODE_BIN}; echo; echo 'Press Enter to close.'; read"],
                start_new_session=True,
            )
            self.settings.set("dev-mode.enabled", True)
            self._status_row.set_subtitle("Enabled — install running in terminal")
        except FileNotFoundError:
            # Fallback: run inline
            subprocess.Popen([DEVMODE_BIN], start_new_session=True)
            self._status_row.set_subtitle("Installing in background")

        # Re-enable after a moment
        GLib.timeout_add_seconds(3, lambda: (btn.set_sensitive(True), btn.set_label("Install"), False)[2])
