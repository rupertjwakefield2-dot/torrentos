"""Accessibility — front-page treatment for screen reader, contrast, scale, etc."""

from __future__ import annotations

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, GLib, Gtk  # noqa: E402

from .. import applier
from ..settings import Settings


SCALE_OPTIONS = [
    ("100%", 1.0),
    ("125%", 1.25),
    ("150%", 1.5),
    ("200%", 2.0),
]


class AccessibilityPage(Adw.PreferencesPage):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.set_name("accessibility")
        self.set_title("Accessibility")
        self.set_icon_name("preferences-desktop-accessibility-symbolic")
        self.settings = settings

        # ----- Vision -----
        vision = Adw.PreferencesGroup()
        vision.set_title("Vision")
        self.add(vision)

        self._add_switch(
            vision,
            title="High contrast",
            subtitle="Increase contrast across UI elements",
            key="accessibility.high-contrast",
            default=False,
        )
        self._add_switch(
            vision,
            title="Screen reader (Orca)",
            subtitle="Reads UI elements aloud — Super+Alt+S to toggle later",
            key="accessibility.screen-reader",
            default=False,
        )

        # UI scale
        scale_row = Adw.ComboRow()
        scale_row.set_title("UI scale")
        scale_row.set_subtitle("Sizes text and interface elements")
        model = Gtk.StringList()
        for label, _ in SCALE_OPTIONS:
            model.append(label)
        scale_row.set_model(model)
        current = float(settings.get("accessibility.ui-scale", 1.0))
        scale_row.set_selected(
            next((i for i, (_, s) in enumerate(SCALE_OPTIONS) if abs(s - current) < 0.01), 0)
        )
        scale_row.connect("notify::selected", self._on_scale_changed)
        vision.add(scale_row)

        # Color filter
        filter_row = Adw.ComboRow()
        filter_row.set_title("Color filter")
        filter_row.set_subtitle("Compensate for color blindness")
        filter_model = Gtk.StringList()
        for label in ("None", "Protanopia (red-blind)", "Deuteranopia (green-blind)", "Tritanopia (blue-blind)"):
            filter_model.append(label)
        filter_row.set_model(filter_model)
        current_filter = settings.get("accessibility.color-filter", "none")
        filter_keys = ["none", "protanopia", "deuteranopia", "tritanopia"]
        filter_row.set_selected(filter_keys.index(current_filter) if current_filter in filter_keys else 0)
        filter_row.connect("notify::selected",
                           lambda r, _: self.settings.set("accessibility.color-filter",
                                                          filter_keys[r.get_selected()]))
        vision.add(filter_row)

        # ----- Keyboard -----
        keyboard = Adw.PreferencesGroup()
        keyboard.set_title("Keyboard")
        self.add(keyboard)

        self._add_switch(
            keyboard,
            title="Sticky keys",
            subtitle="Modifier keys stay pressed for one keystroke",
            key="accessibility.sticky-keys",
            default=False,
        )
        self._add_switch(
            keyboard,
            title="Slow keys",
            subtitle="Require a key to be held briefly before registering",
            key="accessibility.slow-keys",
            default=False,
        )
        self._add_switch(
            keyboard,
            title="Mouse keys",
            subtitle="Move the cursor using the numeric keypad",
            key="accessibility.mouse-keys",
            default=False,
        )

        # ----- Audio / hearing -----
        hearing = Adw.PreferencesGroup()
        hearing.set_title("Hearing")
        self.add(hearing)

        self._add_switch(
            hearing,
            title="Live captions",
            subtitle="Generate captions on-device for any audio",
            key="accessibility.live-captions",
            default=False,
        )

    # ----- helper -----

    def _add_switch(self, group: Adw.PreferencesGroup, *, title: str, subtitle: str, key: str, default: bool) -> Adw.SwitchRow:
        row = Adw.SwitchRow()
        row.set_title(title)
        row.set_subtitle(subtitle)
        row.set_active(bool(self.settings.get(key, default)))
        row.connect("notify::active", lambda r, _: self._on_switch(r, key))
        group.add(row)
        return row

    def _on_switch(self, row: Adw.SwitchRow, key: str) -> None:
        v = row.get_active()
        self.settings.set(key, v)
        applier.apply(key, v)

    def _on_scale_changed(self, row: Adw.ComboRow, _pspec) -> None:
        idx = row.get_selected()
        scale = SCALE_OPTIONS[idx][1]
        self.settings.set("accessibility.ui-scale", scale)
        applier.apply("accessibility.ui-scale", scale)
