"""barpop - the popup shell behind waybar's click menus.

One layer-shell overlay, one stylesheet, and a set of panels that plug into
it: `barpop launcher`, `barpop audio`, `barpop network`, ... Every panel is a
Gtk.Box subclass built from the shared widgets in `widgets.py` and painted by
`style.css` (concatenated after waybar's matugen colors.css, so everything
retints with the wallpaper). Being its own surface rather than a GTK popup on
the bar's layer is what keeps hover/redraw at full refresh under Hyprland.

Extra panels or network sections live in ~/.config/barpop/plugins/*.py, each
module exporting `PANELS = [PanelSubclass, ...]` and/or
`NETWORK_SECTIONS = [SectionSubclass, ...]`; see panels/__init__.py.
"""
