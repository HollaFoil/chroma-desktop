# dotfiles

A Hyprland desktop where every colour comes from the wallpaper. Change the
wallpaper (`SUPER+W`) and matugen recolours the bar, notifications, launcher,
terminal, lock screen, GTK and Qt apps, Discord, Spotify, Steam, btop, the
shell prompt and the websites you visit in Firefox — live, no restarts.

Written for CachyOS/Arch. Hyprland is configured in **Lua** (`hyprland.lua`
and `hypr/conf/*.lua`, read natively by Hyprland ≥ 0.56; there is no conversion
step), and the parts worth tweaking have a **Settings** window (Arch button).

## Layout

```
manifest.txt        every file that gets symlinked into ~, one path per line
files/              the dotfiles themselves, mirrored on ~ (files/.config/... -> ~/.config/...)
packages.txt        what to install and why; read by ./bootstrap
bootstrap           first-time setup (--check to only report, --monitors for your displays)
link / adopt        symlink the manifest into ~ / pull live files back into the repo
prune               list (or --remove) packages this setup makes redundant: dolphin, haruna, gwenview, vlc...
examples/           relayout.config.sh, hypr-user.lua: per-machine files that live outside the repo
wallpapers/         one default wallpaper, so a fresh clone has colours before you pick your own
hyprtest            integration test for the window-management scripts (moves windows around)
```

## Install

```sh
git clone https://github.com/HollaFoil/dotfiles ~/dotfiles
cd ~/dotfiles
./bootstrap --check                  # what is missing, changes nothing
./bootstrap --wallpaper ~/Pictures/some.png
```

Needs **Hyprland ≥ 0.56**: the config is Lua, and older versions cannot read it
at all, so you would log into a session with no config rather than a broken
one. `./bootstrap --check` says so if yours is too old.

`bootstrap` installs the packages you approve (pacman, and paru/yay for the
AUR entries), lists what `./prune --remove` would uninstall, symlinks the manifest (anything already in the way is moved to
`backup-<timestamp>/` in the repo), renders the one file that needs your home
path baked in (Firefox's native-messaging manifest), enables `waybar.service`,
offers to write your monitors and to make fish your login shell,
sets up whichever of Steam/Spotify/Discord/btop/oh-my-posh you have, and runs
`setwall` on the wallpaper so the colour files exist before your first login.

That last step matters: waybar, rofi, hyprlock and swaync `@import` files that
matugen generates. Without one `setwall` run there is no styling and hyprlock
refuses to start. So if you have no wallpapers of your own yet, bootstrap
copies `wallpapers/default.jpg` into `~/Pictures/Wallpapers` and uses that —
a fresh clone comes up themed, not unstyled. The Hyprland config
(`hypr/lib/palette.lua`) has a built-in fallback palette.

Then log into Hyprland. It starts `hyprland-session.target` (which pulls in
waybar), swaync, the wallpaper daemon, clipboard history, hypridle and the
dashboard.

### Make it yours

Start with your monitors:

```sh
./bootstrap --monitors      # = gen-monitors, from inside a Hyprland session
```

Monitor names appear in three places that have to agree, and `gen-monitors`
writes all of them from `hyprctl monitors`: the output list
(`hypr/monitors.lua`), the workspace → monitor map
(`hypr/state/monitors.json`, read by `hypr/lib/workspaces.lua`) and the bar's
`persistent-workspaces` and workspace labels. Or keep using `nwg-displays` for
the geometry and run `gen-monitors` after it.

You do not have to run it at all, though: with no state file the same map is
derived live from `hl.get_monitors()`, and a workspace rule naming a monitor
you do not have is dropped rather than pinning that workspace to nothing. One
screen works out of the box; running `gen-monitors` is what teaches the *bar*
about your monitors, which it cannot work out for itself.

### Workspaces are per monitor

Each monitor owns five workspaces, and `SUPER+1`…`5` means *the Nth workspace
of the monitor the pointer is over* — point somewhere else and the same five
keys drive that screen. `SUPER+SHIFT+1`…`5` throws the focused window there,
which is also how a window crosses monitors. Nothing is bound past 5.

Underneath, ids are banked — the primary monitor owns 1–5, the next 11–15, the
third 21–25 — because Hyprland has a single global set of workspaces and only
one of them can be "1". Nobody types those: `hypr/lib/workspaces.lua` maps the
keys onto the pointed monitor's bank, and waybar's `format-icons` relabels each
bank `1`–`5`. Changing `PER_MON` there (and in `gen-monitors`) changes how many
each monitor gets.

The rest are one machine's values:

| What | Where | Note |
|---|---|---|
| CPU temperature | `files/.config/waybar/config.jsonc` → `temperature.hwmon-path-abs` | Points at an AMD `k10temp` PCI path. Use `thermal-zone` or your own hwmon path. |
| Keyboard layout, terminal, file manager | Settings > Input (`kb_layout`), `files/.config/hypr/conf/actions.lua` (`terminal`, `fileManager` at the top) | Nemo is GTK3, so it follows the palette live; a Qt file manager would not. |
| Wallpapers folder | `~/Pictures/Wallpapers` | `SUPER+W` browses it; `WALLSTRIP_DIR` overrides. |
| The dashboard (`relayout`) | `~/.config/relayout/config.sh` | Opt-in, see below. |
| Machine-local Hyprland extras | `~/.config/hypr/user/init.lua` | Loaded if present; `examples/hypr-user.lua` shows a new action and an override. |
| Per-site Firefox styles | `files/.config/dusky_sites/*.css` | One file per site. Your own services belong in a private overlay repo — `.gitignore` has an entry showing how. |

### relayout is opt-in

`relayout` puts a fixed dashboard of apps (Spotify, Slack, Discord, btop) on a
fixed monitor. That is one machine's habit, so nothing is bound to it until you
say so: write `~/.config/relayout/config.sh` (start from
`examples/relayout.config.sh`) and `SUPER+SHIFT+R` / `SUPER+ALT+R` appear, and
`relayout --boot` starts those apps at login. Without that file the two actions
are still listed in Settings > Keybinds — bind them there if you want them —
but they have no keys and nothing launches uninvited.

## What is in it

| Piece | Role |
|---|---|
| **Hyprland** (`hypr/hyprland.lua` + `hypr/conf/*.lua`) | Compositor config, one topic per file: `look` (gaps, blur, animations), `input`, `rules`, `autostart`, `actions` (every keybind as a named action). `lib/` holds the palette (matugen's `colors.lua`), the action registry, the settings-override loader and the workspace → monitor map; `state/*.json` is what the Settings window wrote. |
| **waybar** | Bar; runs as a `systemd --user` unit so a crash restarts it. Custom modules feed from `waybar-widget` (media, GPU). |
| **swaync** | Notifications and control centre. |
| **rofi** | Launcher (`SUPER+R`) and clipboard history (`SUPER+SHIFT+C`, via cliphist). Styles paint crops of the current wallpaper. |
| **kitty**, **fish**, **oh-my-posh** | Terminal and shell; the prompt theme is recoloured per wallpaper. `config.fish` only does anything if fish is your login shell — bootstrap offers the `chsh`. |
| **hyprlock / hypridle** | Lock and idle. |
| **matugen** | The colour engine: one template per app in `matugen/templates/`, wired in `matugen/config.toml`. |
| **awww** | Wallpaper daemon (swww fork). |
| Layer-shell overlays (Python + GTK3) | `barpop` (the bar's menus and the **Settings** window), `cheatsheet` (`SUPER+/`), `wallstrip` (`SUPER+W`, wallpaper picker). |
| `relayout` | Puts a fixed "dashboard" of apps — Spotify, Slack, Discord, btop — on one monitor (`SUPER+SHIFT+R`), or on the other (`SUPER+ALT+R`), parking the rest in a scratchpad. Opt-in: unbound until `~/.config/relayout/config.sh` exists. |
| `setwall` | `awww` → `matugen` → rofi thumbnails → prompt colours. Everything downstream is a matugen `post_hook`. |
| `gen-monitors` | Writes this machine's monitors, its per-monitor workspace banks and the bar's workspace buttons and labels, from `hyprctl monitors`. |

## Settings

Arch button (top left) → **Settings**, or `SUPER+,`, or `barpop settings
[--page look]`. A layer-shell window, so it floats over everything and is not
tiled. Pages:

- **About PC** — the fastfetch view: OS, kernel, Hyprland/waybar/matugen
  versions, theme, board, BIOS, CPU, GPUs and drivers, memory, disks, displays;
  *Copy* puts it on the clipboard for a bug report.
- **Keybinds** — every action from `conf/actions.lua` with its keys. Click a key
  (or `+`) and press the new combination; while recording, Hyprland sits in an
  empty `capture` submap so `SUPER+…` reaches the window instead of firing.
  Multiple keys per action, per-action cheatsheet checkbox, ↺ back to the
  config's default, **Add command** for a shell-command action without touching
  Lua. Writes `hypr/state/keybinds.json` and reloads Hyprland.
- **Windows / Look / Input** — curated Hyprland options (layout, gaps, blur,
  opacity, mouse, touchpad …). Sliders and switches apply live via
  `hyprctl eval`, and the value is stored in `hypr/state/settings.json`, which
  `hyprland.lua` re-applies on every reload. ● marks an override; ↺ removes it
  (the value from `conf/*.lua` returns).
- **All options** — everything `hyprctl descriptions` knows, typed from its
  schema, with a filter box.
- **Wallpapers** — thumbnail grid → `setwall`. **Monitors** — what is connected
  and a button to `nwg-displays` (which writes `monitors.lua`; `gen-monitors`
  writes the workspace map to match).
- **Wi-Fi / Bluetooth / Connections / Audio** — the bar's audio and network
  popups (`barpop audio`, `barpop network`, opened from their bar modules) taken
  apart into pages: Wi-Fi scans while open, Bluetooth discovers while the page
  is on screen, Connections has wired/Tailscale and the nm-connection-editor
  button, Audio is the full mixer with the per-app rows open.
- **Per-app output** — every stream's row (in Settings > Audio and in the bar's
  audio popup) has a `Device ▾`: send that app somewhere other than the default
  output, for *this stream* (one Firefox tab; forgotten when it ends), *this
  app until logout* (rule in `$XDG_RUNTIME_DIR`), or *this app always* (rule in
  `barpop/audio.json`, in the repo). `barpop watch` applies the rules to streams
  as they appear and when a device comes back. Bootstrap turns off WirePlumber's
  own stream-target memory (`node.stream.restore-target`) so a one-off move
  does not quietly become permanent.

The nav is grouped: System, Desktop, Hardware, Network, Advanced (`GROUPS` in
`barpop/panels/settings/pages/__init__.py`; a page names its group).

Both state files live in the repo (they are in the manifest), so your tweaks
travel with your dotfiles and show up in `git diff`.

**Adding an action** (a keybind): one `A.define{...}` in `conf/actions.lua`, or
in `~/.config/hypr/user/init.lua` for machine-local extras that stay out of the
repo (`examples/hypr-user.lua` shows both a new action and an override of a
built-in). `id` is what the JSON state keys on, so keep it stable. The
cheatsheet (`SUPER+/`) and the Keybinds page both read `~/.cache/hypr/binds.json`,
which the config writes at the end of every load — there is no list to keep in
sync by hand.

## Packages

`packages.txt` is the authoritative list with a purpose per line;
`./bootstrap --check` diffs it against your system. Summary:

- **Core**: hyprland ≥ 0.56, hypridle, hyprlock, hyprpolkitagent, xdg-desktop-portal(-hyprland, -gtk), waybar, swaync, rofi 2.x, kitty, wl-clipboard, cliphist, grim, slurp, pipewire (+pulse, wireplumber), playerctl, networkmanager, matugen, awww, brightnessctl, fish, jq, python + python-gobject + python-cairo, gtk3, gtk-layer-shell, imagemagick (IM7), adw-gtk-theme, adwaita-icon-theme, breeze + breeze-icons, plasma-integration, nemo (+ nemo-terminal, nemo-fileroller, file-roller).
- **Fonts**: `otf-geist-mono-nerd` (UI), `ttf-meslo-nerd` (fallback), `ttf-jetbrains-mono-nerd` (kitty), `noto-fonts`.
- **Themed apps (optional)**: btop, spotify-launcher (+ spicetify), steam, firefox, capitaine-cursors.
- **AUR**: slack-desktop, google-chrome, oh-my-posh-bin, vesktop, vscodium-bin, waybar-git (the reference machine runs `waybar-git` for an mpris crash fix; `extra/waybar` 0.15 works). CachyOS carries vesktop and vscodium in its own repos, plain Arch does not — hence the `[aur]` section.

Not packaged, installed by hand where wanted: [spicetify](https://spicetify.app),
the [MatugenFox](https://github.com/Ubaidullah-Web-Dev/MatugenFox) Firefox extension,
[Adwaita-for-Steam](https://github.com/tkashkin/Adwaita-for-Steam) (bootstrap clones it).

## App integrations

Each is optional; matugen writes the file regardless and the app picks it up
only once configured. `bootstrap` prints which of these still need a step.

- **Steam** — Adwaita-for-Steam skin with the palette as its colour theme, re-installed on every `setwall` (also repairs Steam-update wipes). `reload-steam-css` pushes the new colours into the running client over Steam's DevTools port, which Steam hardcodes to **8080** — that port must be free. Bootstrap creates the flag file `~/.steam/steam/.cef-enable-remote-debugging`. Store/Community pages are websites and stay Steam-coloured.
- **Spotify** — spicetify with the vendored `Text` theme; `spicetify watch -s` (started by hyprland.lua) reloads it in place. Set `current_theme = Text` and `color_scheme = matugen` in `~/.config/spicetify/config-xpui.ini`.
- **Discord (Vesktop)** — generated `quickCss.css`; turn on *Enable Custom CSS* in Vencord settings.
- **Firefox** — MatugenFox extension + `matugenfox-host` (a native-messaging host; bootstrap renders its manifest with your home path). Per-site CSS lives in `dusky_sites/`, one file per site, each wrapped in `@-moz-document domain("…")` — the host reads the domain out of that line and falls back to the file name, so a file using `url-prefix(...)` instead is silently served for a domain that does not exist.
- **VSCodium / VS Code** — install the *Matugen Theme* extension (`haikalllp.matugen-theme`); it watches `~/.cache/matugen/vscode-colors{,.json}` and reloads the editor theme live.
- **btop** — set `color_theme = "matugen"`; `reload-btop` repaints running instances (btop ≥ 1.4.7).
- **GTK / Qt** — `adw-gtk3-dark` with generated `colors.css`; Qt via `plasma-integration` and `kdeglobals`. A `Matugen.colors` KDE scheme is generated but nothing applies it automatically.
- **Icons** — `matugen-icons` builds `~/.local/share/icons/Matugen` on every `setwall`: Adwaita's folders and file-type accents with their blues remapped onto the primary, the rest of Adwaita symlinked in, `breeze-dark` inherited for app icons. Needs `adwaita-icon-theme`; bootstrap selects the theme in gsettings (kdeglobals is linked). Nemo repaints live.
- **Viewers** — images open in **swayimg** (floats centred, Enter for the
  gallery, colours from `swayimg/colors.lua` which matugen writes), video in
  **mpv** with the **ModernZ** OSC (AUR `mpv-modernz-git` + `mpv-thumbfast-git`):
  Jellyfin-style bar, title, rounded seekbar with hover previews, subtitle and
  audio buttons; `keep-open`, no scaling with the window, colours from
  `templates/modernz.conf`. Bootstrap registers both (and nemo, firefox) as the
  xdg defaults for their file types.
- **oh-my-posh** — `gen-ohmyposh-template` recolours the `agnoster` theme; needs `~/.config/oh-my-posh/themes/agnoster.omp.json` (bootstrap offers to fetch it). fish skips the prompt if either is missing.

## Day to day

- `setwall <image>` or `SUPER+W` — new wallpaper and palette everywhere.
- `SUPER+RMB` drag resizes; `SUPER+SHIFT+RMB` drag resizes *keeping the
  window's aspect ratio*, and `SUPER+SHIFT+T` snaps the window to 16:9 first
  (video). Both are exact on floating windows; a tiled window's size belongs to
  the layout, which no ratio can be held against.
- Edit a file in `files/`; it is live immediately (symlinks). Templates take effect on the next `setwall`.
- Added a new config? Append its path to `manifest.txt`, `./adopt` (copies it in), `./link` (replaces it with a symlink).
- KDE's `kde-gtk-config` occasionally rewrites `~/.config/gtk-{3,4}.0/gtk.css` as regular files; `./link` puts the symlinks back.
- `./hyprtest` exercises `relayout` end to end (~3 min, moves windows).
- Changed monitors? `./bootstrap --monitors` again.

## Known personal bits

Honest list of what is tuned to one machine and only *degrades* elsewhere:
`relayout`'s built-in layout (three monitors, five specific apps — but it is
unbound until you write your own config), `waybar-widget`'s media module
(follows the `spotify` player only) and GPU module (`nvidia-smi`; shows `--`
otherwise), `chrome-flags.conf` (NVIDIA workarounds), and the waybar
temperature sensor path.

Anything genuinely mine rather than the desktop's — the site styles for my own
services, a patched PKGBUILD — lives in a separate private overlay repo that
symlinks itself in on top of this one. `.gitignore` keeps its files out of
`git status` here; do the same rather than committing your own hostnames.
