"""Appearance page — theme, accent colour, font, animations, wallpaper."""

from __future__ import annotations

from pathlib import Path

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gio, Gtk  # noqa: E402

from .. import applier
from ..settings import Settings


THEMES = [
    ("dark",  "Dark"),
    ("light", "Light"),
    ("auto",  "Follow system"),
]

ACCENTS = [
    ("Torrent Blue",  "#1E6FFF"),
    ("Surge",         "#5BC0EB"),
    ("Riptide",       "#FF6B6B"),
    ("Foam Green",    "#5BEBA1"),
    ("Storm Purple",  "#C678DD"),
    ("Solar",         "#FFB454"),
    ("Rose",          "#FF79C6"),
    ("Sand",          "#E8C97B"),
]

FONT_SIZES = [9, 10, 11, 12, 13, 14, 16]


class AppearancePage(Adw.PreferencesPage):
    def __init__(self, settings: Settings) -> None:
        super().__init__()
        self.set_name("appearance")
        self.set_title("Appearance")
        self.set_icon_name("preferences-desktop-wallpaper-symbolic")
        self.settings = settings

        # ── Theme group ──────────────────────────────────────────────────────
        theme_group = Adw.PreferencesGroup()
        theme_group.set_title("Theme")
        theme_group.set_description("Global colour scheme for the desktop and apps")
        self.add(theme_group)

        theme_row = Adw.ComboRow()
        theme_row.set_title("Colour scheme")
        theme_row.set_subtitle("Applies to GTK apps and the Hyprland compositor")
        theme_model = Gtk.StringList()
        for _, label in THEMES:
            theme_model.append(label)
        theme_row.set_model(theme_model)
        current = settings.get("appearance.theme", "dark")
        theme_row.set_selected(next((i for i, (k, _) in enumerate(THEMES) if k == current), 0))
        theme_row.connect("notify::selected", self._on_theme_changed)
        theme_group.add(theme_row)

        # ── Accent colour group ──────────────────────────────────────────────
        accent_group = Adw.PreferencesGroup()
        accent_group.set_title("Accent colour")
        accent_group.set_description("Tints buttons, focus rings, and window borders")
        self.add(accent_group)

        swatch_row = Adw.ActionRow()
        swatch_row.set_title("Colour")
        swatch_row.set_activatable(False)

        swatch_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        swatch_box.set_valign(Gtk.Align.CENTER)
        swatch_box.set_margin_top(8)
        swatch_box.set_margin_bottom(8)

        current_accent = settings.get("appearance.accent", "#1E6FFF").lower()
        self._accent_buttons: list[tuple[Gtk.Button, str]] = []
        for name, hex_color in ACCENTS:
            btn = self._make_accent_swatch(name, hex_color, selected=hex_color.lower() == current_accent)
            swatch_box.append(btn)
            self._accent_buttons.append((btn, hex_color))

        swatch_row.add_suffix(swatch_box)
        accent_group.add(swatch_row)

        # ── Font group ───────────────────────────────────────────────────────
        font_group = Adw.PreferencesGroup()
        font_group.set_title("Fonts")
        font_group.set_description("Interface font settings")
        self.add(font_group)

        font_size_row = Adw.SpinRow.new_with_range(9, 16, 1)
        font_size_row.set_title("Interface font size")
        font_size_row.set_subtitle("Affects GTK applications and system UI")
        current_size = int(settings.get("appearance.font-size", 11))
        font_size_row.set_value(current_size)
        font_size_row.connect("notify::value", self._on_font_size_changed)
        font_group.add(font_size_row)

        # ── Effects group ────────────────────────────────────────────────────
        effects_group = Adw.PreferencesGroup()
        effects_group.set_title("Effects")
        effects_group.set_description("Visual effects and compositor options")
        self.add(effects_group)

        anim_row = Adw.SwitchRow()
        anim_row.set_title("Animations")
        anim_row.set_subtitle("Window open/close and workspace transitions")
        anim_row.set_active(bool(settings.get("appearance.animations", True)))
        anim_row.connect("notify::active", self._on_animations_toggled)
        effects_group.add(anim_row)

        blur_row = Adw.SwitchRow()
        blur_row.set_title("Background blur")
        blur_row.set_subtitle("Gaussian blur on transparent panel backgrounds")
        blur_row.set_active(bool(settings.get("appearance.blur", True)))
        blur_row.connect("notify::active", self._on_blur_toggled)
        effects_group.add(blur_row)

        rounding_row = Adw.SpinRow.new_with_range(0, 24, 2)
        rounding_row.set_title("Window corner radius")
        rounding_row.set_subtitle("Pixels — 0 for sharp corners, 12 is the default")
        rounding_row.set_value(int(settings.get("appearance.rounding", 12)))
        rounding_row.connect("notify::value", self._on_rounding_changed)
        effects_group.add(rounding_row)

        # ── Wallpaper group ──────────────────────────────────────────────────
        wallpaper_group = Adw.PreferencesGroup()
        wallpaper_group.set_title("Wallpaper")
        self.add(wallpaper_group)

        current_wp = settings.get("appearance.wallpaper", "/usr/share/torrentos/branding/wallpaper.png")
        self._wp_row = Adw.ActionRow()
        self._wp_row.set_title("Current wallpaper")
        self._wp_row.set_subtitle(Path(current_wp).name)
        wp_btn = Gtk.Button(label="Choose…")
        wp_btn.add_css_class("suggested-action")
        wp_btn.set_valign(Gtk.Align.CENTER)
        wp_btn.connect("clicked", self._on_wallpaper_clicked)
        self._wp_row.add_suffix(wp_btn)
        wallpaper_group.add(self._wp_row)

        reset_row = Adw.ActionRow()
        reset_row.set_title("Restore default wallpaper")
        reset_row.set_subtitle("Resets to the built-in TorrentOS wallpaper")
        reset_btn = Gtk.Button(label="Reset")
        reset_btn.add_css_class("flat")
        reset_btn.set_valign(Gtk.Align.CENTER)
        reset_btn.connect("clicked", self._on_wallpaper_reset)
        reset_row.add_suffix(reset_btn)
        wallpaper_group.add(reset_row)

    # ── Helpers ──────────────────────────────────────────────────────────────

    def _make_accent_swatch(self, name: str, hex_color: str, *, selected: bool) -> Gtk.Button:
        btn = Gtk.Button()
        btn.set_size_request(32, 32)
        btn.set_tooltip_text(name)
        ring = "inset 0 0 0 3px white, 0 0 0 2px " + hex_color if selected else "none"
        css = Gtk.CssProvider()
        css.load_from_data(
            f"button {{ background: {hex_color}; border-radius: 16px; "
            f"min-width: 32px; min-height: 32px; padding: 0; "
            f"box-shadow: {ring}; }}".encode()
        )
        btn.get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        btn.connect("clicked", self._on_accent_clicked, hex_color)
        return btn

    def _refresh_swatches(self, selected_hex: str) -> None:
        """Update the ring on all swatches to reflect the new selection."""
        for btn, hex_color in self._accent_buttons:
            selected = hex_color.lower() == selected_hex.lower()
            ring = "inset 0 0 0 3px white, 0 0 0 2px " + hex_color if selected else "none"
            css = Gtk.CssProvider()
            css.load_from_data(
                f"button {{ background: {hex_color}; border-radius: 16px; "
                f"min-width: 32px; min-height: 32px; padding: 0; "
                f"box-shadow: {ring}; }}".encode()
            )
            ctx = btn.get_style_context()
            # Remove old providers (best-effort)
            ctx.add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    # ── Handlers ─────────────────────────────────────────────────────────────

    def _on_theme_changed(self, row: Adw.ComboRow, _pspec) -> None:
        key = THEMES[row.get_selected()][0]
        self.settings.set("appearance.theme", key)
        applier.apply("appearance.theme", key)

    def _on_accent_clicked(self, _btn: Gtk.Button, hex_color: str) -> None:
        self.settings.set("appearance.accent", hex_color)
        applier.apply("appearance.accent", hex_color)
        self._refresh_swatches(hex_color)

    def _on_font_size_changed(self, row: Adw.SpinRow, _pspec) -> None:
        size = int(row.get_value())
        self.settings.set("appearance.font-size", size)
        applier.apply("appearance.font-size", size)

    def _on_animations_toggled(self, row: Adw.SwitchRow, _pspec) -> None:
        v = row.get_active()
        self.settings.set("appearance.animations", v)
        applier.apply("appearance.animations", v)

    def _on_blur_toggled(self, row: Adw.SwitchRow, _pspec) -> None:
        v = row.get_active()
        self.settings.set("appearance.blur", v)
        applier.apply("appearance.blur", v)

    def _on_rounding_changed(self, row: Adw.SpinRow, _pspec) -> None:
        v = int(row.get_value())
        self.settings.set("appearance.rounding", v)
        applier.apply("appearance.rounding", v)

    def _on_wallpaper_clicked(self, _btn: Gtk.Button) -> None:
        dialog = Gtk.FileDialog()
        dialog.set_title("Choose wallpaper")
        f = Gtk.FileFilter()
        f.set_name("Images")
        for ext in ("png", "jpg", "jpeg", "webp", "bmp"):
            f.add_pattern(f"*.{ext}")
        filters = Gio.ListStore.new(Gtk.FileFilter)
        filters.append(f)
        dialog.set_filters(filters)
        dialog.open(self.get_root(), None, self._on_wallpaper_picked)

    def _on_wallpaper_picked(self, dialog: Gtk.FileDialog, result) -> None:
        try:
            file = dialog.open_finish(result)
        except Exception:
            return
        path = file.get_path()
        if not path:
            return
        self.settings.set("appearance.wallpaper", path)
        applier.apply("appearance.wallpaper", path)
        self._wp_row.set_subtitle(Path(path).name)

    def _on_wallpaper_reset(self, _btn: Gtk.Button) -> None:
        default = "/usr/share/torrentos/branding/wallpaper.png"
        self.settings.reset("appearance.wallpaper")
        applier.apply("appearance.wallpaper", default)
        self._wp_row.set_subtitle(Path(default).name)
