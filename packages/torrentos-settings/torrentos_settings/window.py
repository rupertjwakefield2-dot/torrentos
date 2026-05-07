"""Main TorrentOS Settings window — sidebar + content area, libadwaita-style."""

from __future__ import annotations

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gio, GLib, Gtk  # noqa: E402

from .pages.appearance import AppearancePage
from .pages.accessibility import AccessibilityPage
from .pages.display import DisplayPage
from .pages.keyboard import KeyboardPage
from .pages.network import NetworkPage
from .pages.dev_mode import DevModePage
from .pages.about import AboutPage
from .settings import Settings


PAGES: list[tuple[str, str, str, type]] = [
    # (id, title, icon-name, page-class)
    ("appearance",    "Appearance",      "preferences-desktop-wallpaper-symbolic", AppearancePage),
    ("display",       "Display",         "video-display-symbolic",                 DisplayPage),
    ("keyboard",      "Keyboard & Mouse","input-keyboard-symbolic",                KeyboardPage),
    ("network",       "Network",         "network-wireless-symbolic",              NetworkPage),
    ("accessibility", "Accessibility",   "preferences-desktop-accessibility-symbolic", AccessibilityPage),
    ("dev_mode",      "Dev Mode",        "applications-development-symbolic",      DevModePage),
    ("about",         "About",           "help-about-symbolic",                    AboutPage),
]


class SettingsWindow(Adw.ApplicationWindow):
    def __init__(self, *, application: Adw.Application, settings: Settings) -> None:
        super().__init__(application=application)
        self.settings = settings
        self.set_title("TorrentOS Settings")
        self.set_default_size(960, 640)
        self.set_size_request(720, 520)

        # Layout: NavigationSplitView for the sidebar + content pane (macOS-feel).
        split = Adw.NavigationSplitView()
        split.set_min_sidebar_width(210)
        split.set_max_sidebar_width(290)
        split.set_sidebar_width_fraction(0.27)
        self.set_content(split)

        # ── Sidebar ──────────────────────────────────────────────────────────
        sidebar_page = Adw.NavigationPage()
        sidebar_page.set_title("Settings")

        sidebar_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)

        sidebar_header = Adw.HeaderBar()
        sidebar_header.add_css_class("flat")

        # Search button in sidebar header
        search_btn = Gtk.ToggleButton()
        search_btn.set_icon_name("edit-find-symbolic")
        search_btn.set_tooltip_text("Search settings")
        sidebar_header.pack_end(search_btn)
        sidebar_box.append(sidebar_header)

        # Search bar
        search_bar = Gtk.SearchBar()
        search_entry = Gtk.SearchEntry()
        search_entry.set_placeholder_text("Search…")
        search_bar.set_child(search_entry)
        search_bar.set_show_close_button(False)
        search_btn.bind_property("active", search_bar, "search-mode-enabled",
                                 GLib.BindingFlags.BIDIRECTIONAL)
        sidebar_box.append(search_bar)

        scroller = Gtk.ScrolledWindow()
        scroller.set_vexpand(True)
        scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sidebar_box.append(scroller)

        self.list_box = Gtk.ListBox()
        self.list_box.add_css_class("navigation-sidebar")
        self.list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.list_box.connect("row-selected", self._on_row_selected)
        self.list_box.set_filter_func(self._filter_rows)
        search_entry.connect("search-changed", self._on_search_changed)
        scroller.set_child(self.list_box)

        sidebar_page.set_child(sidebar_box)
        split.set_sidebar(sidebar_page)

        # ── Content ──────────────────────────────────────────────────────────
        self.content_stack = Gtk.Stack()
        self.content_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.content_stack.set_transition_duration(160)

        self.content_page = Adw.NavigationPage()
        self.content_page.set_title("Appearance")  # updated on page switch

        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content_header = Adw.HeaderBar()
        content_header.add_css_class("flat")
        content_box.append(content_header)

        # Scrollable content
        content_scroll = Gtk.ScrolledWindow()
        content_scroll.set_vexpand(True)
        content_scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        content_scroll.set_child(self.content_stack)
        content_box.append(content_scroll)

        self.content_page.set_child(content_box)
        split.set_content(self.content_page)

        # ── Populate pages ───────────────────────────────────────────────────
        self._page_instances: dict[str, Gtk.Widget] = {}
        self._row_titles: dict[Gtk.ListBoxRow, str] = {}       # lowercase for search
        self._row_display_titles: dict[Gtk.ListBoxRow, str] = {}  # display titles

        for pid, title, icon, cls in PAGES:
            page_widget = cls(self.settings)
            self.content_stack.add_named(page_widget, pid)
            self._page_instances[pid] = page_widget

            row = Gtk.ListBoxRow()
            row.set_name(pid)
            hbox = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
            hbox.set_margin_start(14)
            hbox.set_margin_end(14)
            hbox.set_margin_top(9)
            hbox.set_margin_bottom(9)
            img = Gtk.Image.new_from_icon_name(icon)
            img.set_pixel_size(18)
            img.add_css_class("dim-label")
            hbox.append(img)
            label = Gtk.Label(label=title, xalign=0)
            label.set_hexpand(True)
            hbox.append(label)
            row.set_child(hbox)
            self.list_box.append(row)
            self._row_titles[row] = title.lower()
            self._row_display_titles[row] = title

        # Select first row by default
        first = self.list_box.get_row_at_index(0)
        if first:
            self.list_box.select_row(first)

        self._search_text = ""

    def _on_row_selected(self, _list_box: Gtk.ListBox, row: Gtk.ListBoxRow | None) -> None:
        if row is None:
            return
        pid = row.get_name()
        self.content_stack.set_visible_child_name(pid)
        # Update the content pane navigation title to the active page name
        display_title = self._row_display_titles.get(row, "Settings")
        self.content_page.set_title(display_title)

    def _on_search_changed(self, entry: Gtk.SearchEntry) -> None:
        self._search_text = entry.get_text().lower()
        self.list_box.invalidate_filter()

    def _filter_rows(self, row: Gtk.ListBoxRow) -> bool:
        if not self._search_text:
            return True
        title = self._row_titles.get(row, "")
        return self._search_text in title
