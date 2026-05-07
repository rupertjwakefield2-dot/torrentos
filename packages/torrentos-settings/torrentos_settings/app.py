"""TorrentOS Settings — Adw.Application entry point."""

from __future__ import annotations

import sys

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gio, Gtk  # noqa: E402

from . import __app_id__, __version__
from .settings import Settings
from .window import SettingsWindow


class TorrentOSSettingsApp(Adw.Application):
    def __init__(self) -> None:
        super().__init__(
            application_id=__app_id__,
            flags=Gio.ApplicationFlags.FLAGS_NONE,
        )
        self.settings = Settings()
        self.connect("activate", self._on_activate)
        self.connect("startup", self._on_startup)

    def _on_startup(self, _app: Adw.Application) -> None:
        # Apply the user's saved colour scheme preference
        theme = self.settings.get("appearance.theme", "dark")
        style = Adw.StyleManager.get_default()
        if theme == "light":
            style.set_color_scheme(Adw.ColorScheme.FORCE_LIGHT)
        elif theme == "auto" and style.get_system_supports_color_schemes():
            style.set_color_scheme(Adw.ColorScheme.DEFAULT)
        else:  # "dark" or unrecognised — default to dark
            style.set_color_scheme(
                Adw.ColorScheme.PREFER_DARK
                if style.get_system_supports_color_schemes()
                else Adw.ColorScheme.FORCE_DARK
            )

        # Ctrl+W / Ctrl+Q closes the focused window
        close_action = Gio.SimpleAction.new("close", None)
        close_action.connect("activate", self._close_window)
        self.add_action(close_action)
        self.set_accels_for_action("app.close", ["<primary>w", "<primary>q"])

        # Ctrl+, opens Settings (idempotent — focuses existing window)
        show_action = Gio.SimpleAction.new("show", None)
        show_action.connect("activate", lambda *_: self._on_activate(self))
        self.add_action(show_action)

    def _close_window(self, _action: Gio.SimpleAction, _param) -> None:
        win = self.props.active_window
        if win:
            win.close()

    def _on_activate(self, app: Adw.Application) -> None:
        win = self.props.active_window
        if not win:
            win = SettingsWindow(application=self, settings=self.settings)
        win.present()


def main() -> int:
    app = TorrentOSSettingsApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
