"""Keyboard & Mouse settings page."""

from __future__ import annotations

import subprocess

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk  # noqa: E402

from .. import applier
from ..settings import Settings


KEYBOARD_LAYOUTS = [
    ("gb", "United Kingdom"),
    ("us", "United States"),
    ("de", "Germany"),
    ("fr", "France"),
    ("es", "Spain"),
    ("it", "Italy"),
    ("pt", "Portugal"),
    ("nl", "Netherlands"),
    ("se", "Sweden"),
    ("no", "Norway"),
    ("dk", "Denmark"),
    ("fi", "Finland"),
    ("pl", "Poland"),
    ("ru", "Russia"),
    ("tr", "Turkey"),
    ("br", "Brazil (ABNT2)"),
    ("jp", "Japan"),
    ("kr", "Korea"),
    ("cn", "China (Pinyin)"),
]


class KeyboardPage(Adw.PreferencesPage):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.set_name("keyboard")
        self.set_title("Keyboard & Mouse")
        self.set_icon_name("input-keyboard-symbolic")
        self.settings = settings

        # ── Keyboard layout group ────────────────────────────────────────────
        kb_group = Adw.PreferencesGroup()
        kb_group.set_title("Keyboard")
        kb_group.set_description("Layout and input behaviour")
        self.add(kb_group)

        layout_row = Adw.ComboRow()
        layout_row.set_title("Layout")
        layout_row.set_subtitle("Takes effect immediately and persists across reboots")
        layout_model = Gtk.StringList()
        for _, label in KEYBOARD_LAYOUTS:
            layout_model.append(label)
        layout_row.set_model(layout_model)
        current_layout = settings.get("keyboard.layout", "gb")
        layout_row.set_selected(
            next((i for i, (k, _) in enumerate(KEYBOARD_LAYOUTS) if k == current_layout), 0)
        )
        layout_row.connect("notify::selected", self._on_layout_changed)
        kb_group.add(layout_row)

        # Repeat delay
        repeat_delay_row = Adw.SpinRow.new_with_range(100, 1000, 50)
        repeat_delay_row.set_title("Key repeat delay")
        repeat_delay_row.set_subtitle("Milliseconds before a held key starts repeating")
        repeat_delay_row.set_value(int(settings.get("keyboard.repeat-delay", 300)))
        repeat_delay_row.connect("notify::value", self._on_repeat_delay_changed)
        kb_group.add(repeat_delay_row)

        # Repeat rate
        repeat_rate_row = Adw.SpinRow.new_with_range(10, 100, 5)
        repeat_rate_row.set_title("Key repeat rate")
        repeat_rate_row.set_subtitle("Characters per second while key is held")
        repeat_rate_row.set_value(int(settings.get("keyboard.repeat-rate", 50)))
        repeat_rate_row.connect("notify::value", self._on_repeat_rate_changed)
        kb_group.add(repeat_rate_row)

        numlock_row = Adw.SwitchRow()
        numlock_row.set_title("Num Lock on startup")
        numlock_row.set_active(bool(settings.get("keyboard.numlock", True)))
        numlock_row.connect("notify::active", self._on_numlock_toggled)
        kb_group.add(numlock_row)

        # ── Mouse group ──────────────────────────────────────────────────────
        mouse_group = Adw.PreferencesGroup()
        mouse_group.set_title("Mouse & Touchpad")
        self.add(mouse_group)

        sensitivity_row = Adw.SpinRow.new_with_range(-1.0, 1.0, 0.1)
        sensitivity_row.set_title("Pointer sensitivity")
        sensitivity_row.set_subtitle("0 is neutral; negative is slower, positive is faster")
        sensitivity_row.set_digits(1)
        sensitivity_row.set_value(float(settings.get("keyboard.mouse-sensitivity", 0.0)))
        sensitivity_row.connect("notify::value", self._on_sensitivity_changed)
        mouse_group.add(sensitivity_row)

        natural_row = Adw.SwitchRow()
        natural_row.set_title("Natural scroll direction")
        natural_row.set_subtitle("Content follows finger movement (macOS-style)")
        natural_row.set_active(bool(settings.get("keyboard.natural-scroll", True)))
        natural_row.connect("notify::active", self._on_natural_scroll_toggled)
        mouse_group.add(natural_row)

        tap_row = Adw.SwitchRow()
        tap_row.set_title("Tap to click")
        tap_row.set_subtitle("Single tap on touchpad acts as a left click")
        tap_row.set_active(bool(settings.get("keyboard.tap-to-click", True)))
        tap_row.connect("notify::active", self._on_tap_toggled)
        mouse_group.add(tap_row)

        # ── Shortcuts group ──────────────────────────────────────────────────
        shortcuts_group = Adw.PreferencesGroup()
        shortcuts_group.set_title("Key shortcuts reference")
        shortcuts_group.set_description("Common TorrentOS keyboard shortcuts")
        self.add(shortcuts_group)

        for action, shortcut in [
            ("App launcher",             "Super + Space"),
            ("Open terminal",            "Super + Return"),
            ("Settings",                 "Super + ,"),
            ("Close window",             "Super + Q"),
            ("File manager",             "Super + E"),
            ("Browser",                  "Super + B"),
            ("Torrent client",           "Super + T"),
            ("VS Code",                  "Super + C"),
            ("System updates",           "Super + U"),
            ("Lock screen",              "Super + L"),
            ("Fullscreen",               "Super + F"),
            ("Float / tile",             "Super + Shift + F"),
            ("Screenshot (region)",      "Super + Shift + S"),
            ("Screenshot (full screen)", "Print"),
            ("Screenshot GUI",           "Super + Ctrl + S"),
            ("Switch workspace",         "Super + 1–9"),
            ("Move window to workspace", "Super + Shift + 1–9"),
            ("Window switcher",          "Super + Tab"),
            ("Notification centre",      "Super + N"),
            ("Clipboard history",        "Super + X"),
            ("Colour picker",            "Super + P"),
            ("Power menu",               "Super + Ctrl + Q"),
        ]:
            row = Adw.ActionRow()
            row.set_title(action)
            label = Gtk.Label(label=shortcut)
            label.add_css_class("caption")
            label.add_css_class("dim-label")
            label.set_halign(Gtk.Align.END)
            row.add_suffix(label)
            shortcuts_group.add(row)

    # ── Handlers ─────────────────────────────────────────────────────────────

    def _on_layout_changed(self, row: Adw.ComboRow, _pspec) -> None:
        code = KEYBOARD_LAYOUTS[row.get_selected()][0]
        self.settings.set("keyboard.layout", code)
        applier.apply("keyboard.layout", code)

    def _on_repeat_delay_changed(self, row: Adw.SpinRow, _pspec) -> None:
        v = int(row.get_value())
        self.settings.set("keyboard.repeat-delay", v)
        applier.apply("keyboard.repeat-delay", v)

    def _on_repeat_rate_changed(self, row: Adw.SpinRow, _pspec) -> None:
        v = int(row.get_value())
        self.settings.set("keyboard.repeat-rate", v)
        applier.apply("keyboard.repeat-rate", v)

    def _on_numlock_toggled(self, row: Adw.SwitchRow, _pspec) -> None:
        v = row.get_active()
        self.settings.set("keyboard.numlock", v)
        applier.apply("keyboard.numlock", v)

    def _on_sensitivity_changed(self, row: Adw.SpinRow, _pspec) -> None:
        v = round(row.get_value(), 1)
        self.settings.set("keyboard.mouse-sensitivity", v)
        applier.apply("keyboard.mouse-sensitivity", v)

    def _on_natural_scroll_toggled(self, row: Adw.SwitchRow, _pspec) -> None:
        v = row.get_active()
        self.settings.set("keyboard.natural-scroll", v)
        applier.apply("keyboard.natural-scroll", v)

    def _on_tap_toggled(self, row: Adw.SwitchRow, _pspec) -> None:
        v = row.get_active()
        self.settings.set("keyboard.tap-to-click", v)
        applier.apply("keyboard.tap-to-click", v)
