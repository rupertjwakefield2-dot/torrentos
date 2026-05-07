"""Display settings — night light, monitor scaling, refresh rate, HiDPI."""

from __future__ import annotations

import subprocess

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk  # noqa: E402

from .. import applier
from ..settings import Settings


SCALES = [
    ("1",    "100%  (standard)"),
    ("1.25", "125%"),
    ("1.5",  "150%"),
    ("1.75", "175%"),
    ("2",    "200%  (HiDPI)"),
    ("2.5",  "250%"),
    ("3",    "300%  (4K / Retina)"),
]


def _get_monitors() -> list[str]:
    try:
        out = subprocess.check_output(
            ["hyprctl", "monitors", "-j"], text=True, timeout=3
        )
        import json
        mons = json.loads(out)
        return [m.get("name", f"Monitor {i}") for i, m in enumerate(mons)]
    except Exception:
        return ["eDP-1", "HDMI-A-1"]


class DisplayPage(Adw.PreferencesPage):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.set_name("display")
        self.set_title("Display")
        self.set_icon_name("video-display-symbolic")
        self.settings = settings

        # ── Night light group ────────────────────────────────────────────────
        nl_group = Adw.PreferencesGroup()
        nl_group.set_title("Night light")
        nl_group.set_description("Shift display colours to warmer tones in the evening")
        self.add(nl_group)

        self._nl_switch = Adw.SwitchRow()
        self._nl_switch.set_title("Enable night light")
        self._nl_switch.set_subtitle("Reduces blue light to ease eye strain — uses gammastep")
        self._nl_switch.set_active(bool(settings.get("display.night-light", False)))
        self._nl_switch.connect("notify::active", self._on_nl_toggled)
        nl_group.add(self._nl_switch)

        self._temp_row = Adw.SpinRow.new_with_range(2700, 6500, 100)
        self._temp_row.set_title("Colour temperature")
        self._temp_row.set_subtitle("2700 K = candlelight  ·  4000 K = warm white  ·  6500 K = daylight")
        self._temp_row.set_value(int(settings.get("display.night-light-temp", 4000)))
        self._temp_row.connect("notify::value", self._on_temp_changed)
        nl_group.add(self._temp_row)

        # ── Scaling group ────────────────────────────────────────────────────
        scale_group = Adw.PreferencesGroup()
        scale_group.set_title("Display scaling")
        scale_group.set_description("Scales all UI elements — takes effect after re-login")
        self.add(scale_group)

        scale_row = Adw.ComboRow()
        scale_row.set_title("Scale factor")
        scale_row.set_subtitle("Use 200% or higher for 4K displays")
        scale_model = Gtk.StringList()
        for _, label in SCALES:
            scale_model.append(label)
        scale_row.set_model(scale_model)
        current_scale = str(settings.get("display.scale", "1"))
        scale_row.set_selected(
            next((i for i, (k, _) in enumerate(SCALES) if k == current_scale), 0)
        )
        scale_row.connect("notify::selected", self._on_scale_changed)
        scale_group.add(scale_row)

        # Custom scale
        custom_scale_row = Adw.SpinRow.new_with_range(0, 4.0, 0.25)
        custom_scale_row.set_title("Custom scale")
        custom_scale_row.set_subtitle("Fine-tune the scale factor — set to 0 to use the preset above")
        custom_scale_row.set_digits(2)
        custom_scale_row.set_value(float(settings.get("display.custom-scale", 0.0)))
        custom_scale_row.connect("notify::value", self._on_custom_scale_changed)
        scale_group.add(custom_scale_row)

        # ── Refresh rate group ───────────────────────────────────────────────
        refresh_group = Adw.PreferencesGroup()
        refresh_group.set_title("Refresh rate")
        refresh_group.set_description("Higher rates reduce motion blur; requires display support")
        self.add(refresh_group)

        refresh_row = Adw.ComboRow()
        refresh_row.set_title("Target refresh rate")
        rates_model = Gtk.StringList()
        for r in ["Auto (preferred)", "60 Hz", "75 Hz", "90 Hz", "120 Hz", "144 Hz", "165 Hz", "240 Hz"]:
            rates_model.append(r)
        refresh_row.set_model(rates_model)
        current_hz = settings.get("display.refresh-rate", "auto")
        rate_map = {"auto": 0, "60": 1, "75": 2, "90": 3, "120": 4, "144": 5, "165": 6, "240": 7}
        refresh_row.set_selected(rate_map.get(str(current_hz), 0))
        refresh_row.connect("notify::selected", self._on_refresh_changed)
        refresh_group.add(refresh_row)

        vrr_row = Adw.SwitchRow()
        vrr_row.set_title("Variable refresh rate (VRR / FreeSync / G-Sync)")
        vrr_row.set_subtitle("Reduces screen tearing; requires VRR-capable display")
        vrr_row.set_active(bool(settings.get("display.vrr", False)))
        vrr_row.connect("notify::active", self._on_vrr_toggled)
        refresh_group.add(vrr_row)

        # ── Colour group ─────────────────────────────────────────────────────
        colour_group = Adw.PreferencesGroup()
        colour_group.set_title("Colour output")
        self.add(colour_group)

        overscan_row = Adw.SpinRow.new_with_range(0, 50, 1)
        overscan_row.set_title("Overscan compensation")
        overscan_row.set_subtitle("Pixels to crop from each edge (useful for some TVs)")
        overscan_row.set_value(int(settings.get("display.overscan", 0)))
        overscan_row.connect("notify::value", self._on_overscan_changed)
        colour_group.add(overscan_row)

    # ── Handlers ─────────────────────────────────────────────────────────────

    def _on_nl_toggled(self, row: Adw.SwitchRow, _pspec) -> None:
        v = row.get_active()
        temp = int(self._temp_row.get_value())
        self.settings.set("display.night-light", v)
        self.settings.set("display.night-light-temp", temp)
        applier.apply_night_light(v, temp)

    def _on_temp_changed(self, row: Adw.SpinRow, _pspec) -> None:
        temp = int(row.get_value())
        self.settings.set("display.night-light-temp", temp)
        if self._nl_switch.get_active():
            applier.apply_night_light(True, temp)

    def _on_scale_changed(self, row: Adw.ComboRow, _pspec) -> None:
        scale = SCALES[row.get_selected()][0]
        self.settings.set("display.scale", scale)
        applier.apply_ui_scale(float(scale))

    def _on_custom_scale_changed(self, row: Adw.SpinRow, _pspec) -> None:
        v = round(row.get_value(), 2)
        self.settings.set("display.custom-scale", v)
        if v == 0.0:
            return  # 0 means "use the preset above", don't apply anything
        applier.apply_ui_scale(v)

    def _on_refresh_changed(self, row: Adw.ComboRow, _pspec) -> None:
        idx = row.get_selected()
        rates = ["auto", "60", "75", "90", "120", "144", "165", "240"]
        hz = rates[idx]
        self.settings.set("display.refresh-rate", hz)
        if hz != "auto":
            applier.apply_refresh_rate(int(hz))

    def _on_vrr_toggled(self, row: Adw.SwitchRow, _pspec) -> None:
        v = row.get_active()
        self.settings.set("display.vrr", v)
        applier.apply_vrr(v)

    def _on_overscan_changed(self, row: Adw.SpinRow, _pspec) -> None:
        v = int(row.get_value())
        self.settings.set("display.overscan", v)
