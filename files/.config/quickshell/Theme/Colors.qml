pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The matugen palette. setwall renders ~/.config/matugen/generated/quickshell.json
// (templates/quickshell.json); this watches it, so every colour bound to a
// property here retints the moment the wallpaper changes. $QS_COLORS overrides
// the path (the greeter reads /etc/greetd/theme/colors.json).
Singleton {
    id: root

    readonly property string path: {
        const env = Quickshell.env("QS_COLORS")
        return (env && env.length > 0) ? env
             : Quickshell.env("HOME") + "/.config/matugen/generated/quickshell.json"
    }

    property var palette: ({})
    property string wallpaper: ""
    property string mode: "dark"
    property bool loaded: false

    FileView {
        path: root.path
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: root.apply(text())
        onLoadFailed: console.warn("Colors: cannot read " + root.path + "; using the fallback palette")
    }

    function apply(text) {
        try {
            const j = JSON.parse(text)
            palette = j.colors ?? {}
            wallpaper = j.wallpaper ?? ""
            mode = j.mode ?? "dark"
            loaded = true
        } catch (e) {
            console.warn("Colors: bad JSON in " + path + ": " + e)
        }
    }

    function get(name, fallback) {
        const v = palette[name]
        return v !== undefined ? v : fallback
    }

    // Material 3 roles, matugen names in camelCase, except that on_* becomes
    // *Fg: QML reads a property called onSurface as a signal handler. Fallbacks are the palette
    // of the reference wallpaper so the shell draws before the first setwall.
    readonly property color primary:                get("primary", "#98ccf9")
    readonly property color primaryFg:              get("on_primary", "#003352")
    readonly property color primaryContainer:       get("primary_container", "#004a74")
    readonly property color primaryContainerFg:     get("on_primary_container", "#cde5ff")
    readonly property color primaryFixed:           get("primary_fixed", "#cde5ff")
    readonly property color primaryFixedDim:        get("primary_fixed_dim", "#98ccf9")
    readonly property color primaryFixedFg:         get("on_primary_fixed", "#001d33")
    readonly property color primaryFixedVariantFg:  get("on_primary_fixed_variant", "#004a74")
    readonly property color secondary:              get("secondary", "#b9c8da")
    readonly property color secondaryFg:            get("on_secondary", "#233240")
    readonly property color secondaryContainer:     get("secondary_container", "#3a4857")
    readonly property color secondaryContainerFg:   get("on_secondary_container", "#d5e4f7")
    readonly property color secondaryFixed:         get("secondary_fixed", "#d5e4f7")
    readonly property color secondaryFixedDim:      get("secondary_fixed_dim", "#b9c8da")
    readonly property color secondaryFixedFg:       get("on_secondary_fixed", "#0e1d2a")
    readonly property color secondaryFixedVariantFg:get("on_secondary_fixed_variant", "#3a4857")
    readonly property color tertiary:               get("tertiary", "#d1bfe7")
    readonly property color tertiaryFg:             get("on_tertiary", "#372a4a")
    readonly property color tertiaryContainer:      get("tertiary_container", "#4e4062")
    readonly property color tertiaryContainerFg:    get("on_tertiary_container", "#eddcff")
    readonly property color tertiaryFixed:          get("tertiary_fixed", "#eddcff")
    readonly property color tertiaryFixedDim:       get("tertiary_fixed_dim", "#d1bfe7")
    readonly property color tertiaryFixedFg:        get("on_tertiary_fixed", "#211534")
    readonly property color tertiaryFixedVariantFg: get("on_tertiary_fixed_variant", "#4e4062")
    readonly property color error:                  get("error", "#ffb4ab")
    readonly property color errorFg:                get("on_error", "#690005")
    readonly property color errorContainer:         get("error_container", "#93000a")
    readonly property color errorContainerFg:       get("on_error_container", "#ffdad6")
    readonly property color background:             get("background", "#101418")
    readonly property color backgroundFg:           get("on_background", "#e0e3e8")
    readonly property color surface:                get("surface", "#101418")
    readonly property color surfaceFg:              get("on_surface", "#e0e3e8")
    readonly property color surfaceVariantFg:       get("on_surface_variant", "#c2c7cf")
    readonly property color surfaceVariant:         get("surface_variant", "#42474e")
    readonly property color surfaceDim:             get("surface_dim", "#101418")
    readonly property color surfaceBright:          get("surface_bright", "#36393e")
    readonly property color surfaceContainerLowest: get("surface_container_lowest", "#0b0e12")
    readonly property color surfaceContainerLow:    get("surface_container_low", "#181c20")
    readonly property color surfaceContainer:       get("surface_container", "#1c2024")
    readonly property color surfaceContainerHigh:   get("surface_container_high", "#272a2e")
    readonly property color surfaceContainerHighest:get("surface_container_highest", "#313539")
    readonly property color surfaceTint:            get("surface_tint", "#98ccf9")
    readonly property color inverseSurface:         get("inverse_surface", "#e0e3e8")
    readonly property color inverseSurfaceFg:       get("inverse_on_surface", "#2d3135")
    readonly property color inversePrimary:         get("inverse_primary", "#1f6390")
    readonly property color outline:                get("outline", "#8c9198")
    readonly property color outlineVariant:         get("outline_variant", "#42474e")
    readonly property color shadow:                 get("shadow", "#000000")
    readonly property color scrim:                  get("scrim", "#000000")
    readonly property color sourceColor:            get("source_color", "#5c8fb8")
}
