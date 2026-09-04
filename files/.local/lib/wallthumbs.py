"""Wallpaper listing and thumbnail cache, shared by wallstrip (SUPER+W) and
the Wallpapers page of barpop settings so both show the same previews.

Wallpapers are every image under WALL_DIR (recursively). Previews are scaled
once with GdkPixbuf to THUMB_W x THUMB_H (16:9, centre-cropped) and cached
under ~/.cache/wallstrip keyed on path + mtime, so reopening is instant.
"""
from __future__ import annotations

import hashlib
import os
import subprocess
from pathlib import Path

import gi

gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf, GLib  # noqa: E402

WALL_DIR = Path(os.environ.get("WALLSTRIP_DIR", Path.home() / "Pictures/Wallpapers"))
CACHE = Path.home() / ".cache/wallstrip"
SETWALL = Path.home() / ".local/bin/setwall"

THUMB_W, THUMB_H = 640, 360        # cached preview size (16:9 letterboxed)


def list_wallpapers() -> list[Path]:
    files = [p for p in sorted(WALL_DIR.rglob("*")) if p.is_file() and not p.name.startswith(".")]
    return files


def thumb_for(path: Path) -> GdkPixbuf.Pixbuf | None:
    CACHE.mkdir(parents=True, exist_ok=True)
    key = hashlib.sha1(f"{path}:{path.stat().st_mtime_ns}".encode()).hexdigest()
    cached = CACHE / f"{key}.png"
    if cached.exists():
        try:
            return GdkPixbuf.Pixbuf.new_from_file(str(cached))
        except GLib.Error:
            cached.unlink(missing_ok=True)
    try:
        src = GdkPixbuf.Pixbuf.new_from_file(str(path))
    except GLib.Error:
        return None  # not an image
    # scale to cover THUMB_W x THUMB_H, then centre-crop
    scale = max(THUMB_W / src.get_width(), THUMB_H / src.get_height())
    w, h = max(THUMB_W, round(src.get_width() * scale)), max(THUMB_H, round(src.get_height() * scale))
    scaled = src.scale_simple(w, h, GdkPixbuf.InterpType.BILINEAR)
    thumb = scaled.new_subpixbuf((w - THUMB_W) // 2, (h - THUMB_H) // 2, THUMB_W, THUMB_H).copy()
    thumb.savev(str(cached), "png", [], [])
    return thumb


def current_wallpaper() -> Path | None:
    try:
        out = subprocess.run(["awww", "query"], capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    for line in out.splitlines():
        if "image: " in line:
            return Path(line.split("image: ", 1)[1].strip())
    return None


def apply(path: Path) -> None:
    """setwall, detached from the caller's lifetime."""
    subprocess.Popen([str(SETWALL), str(path)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)
