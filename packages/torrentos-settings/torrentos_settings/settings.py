"""TorrentOS settings store.

Layered config:
    1. /etc/torrentos/default-settings.toml   (read-only baseline shipped by torrentos-base)
    2. ~/.config/torrentos/settings.toml      (user overrides — written by this app)

Reads merge layers; writes go to the user file only.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import Any

try:
    import tomllib  # Python 3.11+
except ImportError:  # pragma: no cover
    import tomli as tomllib

import tomli_w

DEFAULT_PATH = Path("/etc/torrentos/default-settings.toml")
USER_PATH = Path.home() / ".config" / "torrentos" / "settings.toml"


def _deep_merge(base: dict[str, Any], over: dict[str, Any]) -> dict[str, Any]:
    """Recursive dict merge — over wins."""
    out = dict(base)
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = _deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def _read(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    with path.open("rb") as f:
        return tomllib.load(f)


class Settings:
    """Live settings object. Read merges defaults+user; set persists to user file."""

    def __init__(self) -> None:
        self.defaults = _read(DEFAULT_PATH)
        self.user = _read(USER_PATH)
        self._listeners: list = []

    # ------- public API -------

    def get(self, dotted: str, fallback: Any = None) -> Any:
        """E.g. get('appearance.theme') -> 'dark'."""
        merged = _deep_merge(self.defaults, self.user)
        cur: Any = merged
        for part in dotted.split("."):
            if not isinstance(cur, dict) or part not in cur:
                return fallback
            cur = cur[part]
        return cur

    def set(self, dotted: str, value: Any) -> None:
        """Persist a single key like 'appearance.theme' = 'light'."""
        keys = dotted.split(".")
        cur = self.user
        for k in keys[:-1]:
            if k not in cur or not isinstance(cur[k], dict):
                cur[k] = {}
            cur = cur[k]
        cur[keys[-1]] = value
        self._save()
        for listener in self._listeners:
            try:
                listener(dotted, value)
            except Exception:  # pragma: no cover
                pass

    def reset(self, dotted: str) -> None:
        """Drop a user override and fall back to default."""
        keys = dotted.split(".")
        cur = self.user
        path = []
        for k in keys[:-1]:
            if k not in cur:
                return
            path.append((cur, k))
            cur = cur[k]
        cur.pop(keys[-1], None)
        # Clean up now-empty parent dicts
        for parent, k in reversed(path):
            if not parent[k]:
                parent.pop(k, None)
        self._save()

    def subscribe(self, fn) -> None:
        self._listeners.append(fn)

    # ------- internal -------

    def _save(self) -> None:
        USER_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = USER_PATH.with_suffix(".toml.tmp")
        with tmp.open("wb") as f:
            tomli_w.dump(self.user, f)
        shutil.move(tmp, USER_PATH)
