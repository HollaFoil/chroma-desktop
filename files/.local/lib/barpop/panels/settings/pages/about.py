"""About this PC: the fastfetch view, as a page.

    System    OS · kernel · host · uptime · packages · shell · locale · IP
    Desktop   Hyprland · waybar · matugen · GTK · theme / icons / cursor / font · wallpaper
    Hardware  board · BIOS · CPU · GPUs and drivers · memory · swap · disks · displays · audio

Everything hardware-ish comes from `fastfetch --format json` (one call, in a
thread, so the page opens instantly and fills in); without fastfetch a shorter
list is read straight from /proc and os-release. Desktop rows are ours:
hyprctl, the tools' --version, gsettings. "Copy" puts the whole thing on the
clipboard as text for a bug report.
"""
from __future__ import annotations

import json
import os
import shutil
import socket
import subprocess
import threading
from pathlib import Path

from .... import hypr
from .... import widgets as w
from . import Page
from gi.repository import GLib, Gtk  # noqa: E402

FF_MODULES = "OS:Kernel:Uptime:Packages:Shell:Locale:LocalIp:Loadavg:Board:BIOS:CPU:GPU:Memory:Swap:Disk:Display:Sound:Bluetooth"
COLORS = Path.home() / ".config/waybar/colors.css"
# The palette roles worth a swatch. style.css paints .swatch.<role> with the
# matching @define-color token, so the squares are the live colours.
SWATCHES = ["primary", "secondary", "tertiary", "error", "primary_container",
            "surface", "surface_container_high", "on_surface", "outline"]


# ── helpers ──────────────────────────────────────────────────────────────────

def run(cmd: list[str], timeout: float = 5) -> str:
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        return ""


def gib(n) -> str:
    return f"{(n or 0) / 2**30:.1f} GiB"


def duration(ms: int) -> str:
    s = int(ms // 1000)
    d, s = divmod(s, 86400)
    h, s = divmod(s, 3600)
    m, _ = divmod(s, 60)
    parts = [f"{d}d"] if d else []
    parts += [f"{h}h", f"{m}m"]
    return " ".join(parts)


def gsetting(key: str) -> str:
    return run(["gsettings", "get", "org.gnome.desktop.interface", key]).strip("'")


def fastfetch() -> dict[str, object]:
    if not shutil.which("fastfetch"):
        return {}
    out = run(["fastfetch", "--format", "json", "--structure", FF_MODULES], timeout=15)
    try:
        return {m["type"]: m.get("result") for m in json.loads(out) if "result" in m}
    except ValueError:
        return {}


def fallback() -> dict[str, object]:
    """The rows we can get without fastfetch."""
    info: dict[str, object] = {}
    try:
        rel = dict(line.split("=", 1) for line in Path("/etc/os-release").read_text().splitlines() if "=" in line)
        info["OS"] = {"prettyName": rel.get("PRETTY_NAME", "").strip('"'), "version": rel.get("BUILD_ID", "").strip('"')}
    except OSError:
        pass
    u = os.uname()
    info["Kernel"] = {"release": u.release, "architecture": u.machine}
    try:
        info["Uptime"] = {"uptime": float(Path("/proc/uptime").read_text().split()[0]) * 1000}
        mem = {k.rstrip(":"): int(v.split()[0]) * 1024
               for k, v in (line.split(None, 1) for line in Path("/proc/meminfo").read_text().splitlines())}
        info["Memory"] = {"total": mem["MemTotal"], "used": mem["MemTotal"] - mem["MemAvailable"]}
        for line in Path("/proc/cpuinfo").read_text().splitlines():
            if line.startswith("model name"):
                info["CPU"] = {"cpu": line.split(":", 1)[1].strip(), "cores": {"logical": os.cpu_count()}}
                break
    except (OSError, KeyError, ValueError):
        pass
    return info


# ── the rows ─────────────────────────────────────────────────────────────────

def system_rows(ff: dict) -> list[tuple[str, str]]:
    rows = []
    o = ff.get("OS") or {}
    if o:
        rows.append(("OS", " ".join(x for x in (o.get("prettyName") or o.get("name"), o.get("version")) if x)))
    k = ff.get("Kernel") or {}
    if k:
        rows.append(("Kernel", f"{k.get('release', '')} {k.get('architecture', '')}"))
    rows.append(("Host", socket.gethostname()))
    if ff.get("Uptime"):
        rows.append(("Uptime", duration(ff["Uptime"].get("uptime", 0))))
    p = ff.get("Packages") or {}
    if p:
        detail = ", ".join(f"{v} {k}" for k, v in p.items() if k != "all" and v)
        rows.append(("Packages", f"{p.get('all', '?')}  ({detail})" if detail else str(p.get("all", "?"))))
    # not fastfetch's Shell module: that reports its parent process, which
    # from a popup is python. $SHELL is the login shell.
    shell = os.environ.get("SHELL")
    if shell:
        ver = run([shell, "--version"]).split("\n")[0].replace(Path(shell).name, "").strip()
        rows.append(("Shell", f"{Path(shell).name} {ver.split()[0] if ver else ''}".strip()))
    if ff.get("Locale"):
        rows.append(("Locale", str(ff["Locale"])))
    ips = ff.get("LocalIp") or []
    if ips:
        rows.append(("Local IP", ", ".join(f"{i.get('ipv4', i.get('ipv6', ''))} ({i.get('name')})" for i in ips)))
    la = ff.get("Loadavg")
    if la:
        rows.append(("Load", "  ".join(f"{x:.2f}" for x in la)))
    return rows


def desktop_rows() -> list[tuple[str, str]]:
    rows = []
    v = hypr.hyprctl_json("version") or {}
    if v:
        rows.append(("Hyprland", f"{v.get('version', '')}  ({v.get('tag', '')}, {str(v.get('commit', ''))[:8]})"))
    rows.append(("Session", f"{os.environ.get('XDG_SESSION_TYPE', '?')} · {os.environ.get('XDG_CURRENT_DESKTOP', '?')}"))
    wb = next((l for l in run(["waybar", "--version"]).splitlines() if l.startswith("Waybar")), "")
    if wb:
        rows.append(("waybar", wb.replace("Waybar ", "")))
    mg = run(["matugen", "--version"])
    if mg:
        rows.append(("matugen", mg.replace("matugen ", "")))
    rows.append(("GTK", f"{Gtk.get_major_version()}.{Gtk.get_minor_version()}.{Gtk.get_micro_version()}"))
    qt = run(["qtpaths6", "--qt-version"])
    if qt:
        rows.append(("Qt", qt))
    rows.append(("GTK theme", gsetting("gtk-theme")))
    rows.append(("Icons", gsetting("icon-theme")))
    rows.append(("Cursor", f"{gsetting('cursor-theme')} {gsetting('cursor-size')}px"))
    rows.append(("Font", gsetting("font-name")))
    wall = current_wallpaper_name()
    if wall:
        rows.append(("Wallpaper", wall))
    return rows


def current_wallpaper_name() -> str:
    for line in run(["awww", "query"]).splitlines():
        if "image: " in line:
            return Path(line.split("image: ", 1)[1].strip()).name
    return ""


def palette() -> dict[str, str]:
    """role -> #hex from matugen's colors.css, for the roles in SWATCHES."""
    out = {}
    if COLORS.exists():
        for line in COLORS.read_text().splitlines():
            parts = line.strip().rstrip(";").split()
            if len(parts) == 3 and parts[0] == "@define-color" and parts[1] in SWATCHES:
                out[parts[1]] = parts[2]
    return {r: out[r] for r in SWATCHES if r in out}


def swatch_row(colors: dict[str, str]) -> Gtk.Widget:
    """A strip of identical coloured squares; one caption beside the strip
    names the hovered one (no tooltips: GTK popups lag on a layer surface)."""
    box = w.hbox(8, "swatches")
    strip = w.hbox(4)
    # says "hover" until the first hover, then keeps the last hovered colour
    caption = w.label("hover a swatch for its role and hex", "swatch-caption")
    caption.set_valign(Gtk.Align.CENTER)

    def show(role, hexv):
        caption.set_text(f"{role.replace('_', ' ')}  {hexv}")

    for role, hexv in colors.items():
        cell = Gtk.EventBox()
        cell.set_visible_window(False)
        cell.add(w.klass(Gtk.Box(), "swatch", role))
        cell.connect("enter-notify-event", lambda _c, _e, r=role, h=hexv: show(r, h) or False)
        strip.pack_start(cell, False, False, 0)
    box.pack_start(strip, False, False, 0)
    box.pack_start(caption, False, False, 0)
    return box


def hardware_rows(ff: dict) -> list[tuple[str, str]]:
    rows = []
    b = ff.get("Board") or {}
    if b:
        rows.append(("Board", f"{b.get('vendor', '')} {b.get('name', '')}".strip()))
    bi = ff.get("BIOS") or {}
    if bi:
        rows.append(("BIOS", f"{bi.get('vendor', '')} {bi.get('version', '')} ({bi.get('date', '')}, {bi.get('type', '')})"))
    c = ff.get("CPU") or {}
    if c:
        cores = c.get("cores") or {}
        freq = c.get("frequency") or {}
        text = c.get("cpu", "")
        if cores.get("physical"):
            text += f"  {cores['physical']}c/{cores.get('logical', '?')}t"
        elif cores.get("logical"):
            text += f"  {cores['logical']} threads"
        if freq.get("max"):
            text += f"  up to {freq['max'] / 1000:.2f} GHz"
        rows.append(("CPU", text))
    for g in ff.get("GPU") or []:
        label = "GPU" if g.get("type") != "Integrated" else "iGPU"
        rows.append((label, f"{g.get('vendor', '')} {g.get('name', '')}  ·  {g.get('driver', '')}"))
    m = ff.get("Memory") or {}
    if m:
        rows.append(("Memory", f"{gib(m.get('used'))} / {gib(m.get('total'))}"))
    for sw in ff.get("Swap") or []:
        rows.append(("Swap", f"{gib(sw.get('used'))} / {gib(sw.get('total'))}  ({sw.get('name', '')})"))
    for d in ff.get("Disk") or []:
        if "Subvolume" in (d.get("volumeType") or []):
            continue  # same device as its parent
        by = d.get("bytes") or {}
        pct = f"{by['used'] / by['total'] * 100:.0f}%" if by.get("total") else ""
        rows.append((f"Disk {d.get('mountpoint', '')}", f"{gib(by.get('used'))} / {gib(by.get('total'))}  {pct}  {d.get('filesystem', '')}  {d.get('mountFrom', '')}"))
    for disp in ff.get("Display") or []:
        o = disp.get("output") or {}
        ph = disp.get("physical") or {}
        inches = ""
        if ph.get("width") and ph.get("height"):
            diag = (ph["width"] ** 2 + ph["height"] ** 2) ** 0.5 / 25.4
            inches = f'  {diag:.0f}"'
        rows.append(("Display", f"{disp.get('name', '')}  {o.get('width')}x{o.get('height')} @ {o.get('refreshRate', 0):.0f} Hz{inches}"))
    for snd in ff.get("Sound") or []:
        if "active" in (snd.get("type") or []):
            rows.append(("Audio", f"{snd.get('name', '')}  ({snd.get('platformApi', '')})"))
    for bt in ff.get("Bluetooth") or []:
        rows.append(("Bluetooth", f"{bt.get('name', '')} {bt.get('battery', '')}".strip()))
    return rows


# ── the page ─────────────────────────────────────────────────────────────────

class AboutPage(Page):
    def __init__(self):
        super().__init__("About PC", "󰋽", 0, "System")

    def build(self, panel):
        body = w.vbox(6)
        head = w.hbox(8)
        head.pack_start(w.label(self.title, "settings-title"), True, True, 0)
        self.copy_btn = w.pill_button("󰆏  Copy", self._copy, "small")
        head.pack_end(self.copy_btn, False, False, 0)
        body.pack_start(head, False, False, 0)

        self.status = w.status("reading…")
        body.pack_start(self.status, False, False, 0)
        self.grid = Gtk.Grid(row_spacing=3, column_spacing=18)
        w.klass(self.grid, "settings-page", "about-grid")
        body.pack_start(w.scrolled(self.grid, 580), True, True, 0)
        self.sections: list[tuple[str, list[tuple[str, str]]]] = []
        self.palette_cell = None   # (row index, widget) once rendered
        self.wall_cell = None
        threading.Thread(target=self._collect, daemon=True).start()
        body.colors_changed = self.colors_changed  # the panel calls it when colors.css changes
        return body

    def colors_changed(self) -> None:
        """setwall ran: the swatches already retinted through the CSS tokens,
        but the hex texts (and the copy output) are values, so rebuild them;
        the wallpaper name changed too."""
        colors = palette()
        wall = current_wallpaper_name()
        for _title, rows in self.sections:
            for i, (key, value) in enumerate(rows):
                if isinstance(value, dict) and colors:
                    rows[i] = (key, colors)
                elif key == "Wallpaper" and wall:
                    rows[i] = (key, wall)
        if self.palette_cell is not None and colors:
            row, old = self.palette_cell
            self.grid.remove(old)
            fresh = swatch_row(colors)
            self.grid.attach(fresh, 1, row, 1, 1)
            fresh.show_all()
            self.palette_cell = (row, fresh)
        if self.wall_cell is not None and wall:
            self.wall_cell.set_text(wall)

    def _collect(self) -> None:
        ff = fastfetch() or fallback()
        desktop = desktop_rows()
        colors = palette()
        if colors:
            desktop.append(("Palette", colors))   # rendered as swatches, copied as hex
        sections = [("System", system_rows(ff)), ("Desktop", desktop), ("Hardware", hardware_rows(ff))]
        GLib.idle_add(self._render, sections, bool(shutil.which("fastfetch")))

    def _render(self, sections, have_ff: bool) -> bool:
        self.sections = sections
        row = 0
        for title, rows in sections:
            lbl = w.label(title, "settings-section")
            if row:
                lbl.set_margin_top(10)
            self.grid.attach(lbl, 0, row, 2, 1)
            row += 1
            for key, value in rows:
                k = w.label(key, "about-key")
                k.set_valign(Gtk.Align.START)
                if isinstance(value, dict):
                    v = swatch_row(value)
                    self.palette_cell = (row, v)
                else:
                    v = w.label(value, "about-value")
                    v.set_line_wrap(True)
                    v.set_selectable(True)
                    v.set_xalign(0)
                    if key == "Wallpaper":
                        self.wall_cell = v
                self.grid.attach(k, 0, row, 1, 1)
                self.grid.attach(v, 1, row, 1, 1)
                row += 1
        self.grid.show_all()
        w.set_status(self.status, "" if have_ff else "install fastfetch for board, BIOS, GPU, disk and display details")
        return False

    def _copy(self) -> None:
        lines = []
        for title, rows in self.sections:
            lines.append(f"# {title}")
            lines += [f"{k:<14} {' '.join(f'{r}={h}' for r, h in v.items()) if isinstance(v, dict) else v}"
                      for k, v in rows]
            lines.append("")
        try:
            subprocess.run(["wl-copy"], input="\n".join(lines), text=True, timeout=3)
            w.set_status(self.status, "copied to the clipboard")
        except (OSError, subprocess.TimeoutExpired) as e:
            w.set_status(self.status, f"wl-copy failed: {e}", error=True)


PAGE = AboutPage()
