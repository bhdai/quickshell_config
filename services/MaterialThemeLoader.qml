pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets

// Watches the matugen-generated colors.json and applies its Material 3 palette
// to Appearance.m3colors at runtime. When the file changes on disk (e.g., after
// running apply-colors.sh), a 100 ms debounce timer fires to avoid reading a
// partially-written file, then each color is written into Appearance.m3colors.
//
// If colors.json is missing at startup the shell falls back silently to the
// hardcoded defaults in Appearance.qml — no crash, just a console warning.
Singleton {
    id: root

    // ===========================================================================
    // Public interface
    // ===========================================================================

    // Absolute filesystem path (no "file://" prefix) to the generated palette.
    // The FileView resolves it via Qt.resolvedUrl() so the scheme is added there.
    property string filePath: Directories.generatedMaterialThemePath

    // Force-reload the palette file and reapply all colors. Called implicitly
    // when watchChanges fires, but exposed so callers can trigger it explicitly
    // (e.g., from a shell entry point after apply-colors.sh finishes).
    function reapplyTheme(): void {
        themeFileView.reload();
    }

    // Parse a JSON string containing a flat snake_case Material 3 palette and
    // write each color into the corresponding Appearance.m3colors property.
    //
    // Key conversion:
    //   snake_case  →  camelCase  →  m3<CamelCase>
    //   "on_primary" → "onPrimary" → "m3onPrimary"
    //
    // If JSON.parse() throws (malformed file, empty file mid-write, etc.) the
    // error is logged and no colors are modified — the previous palette remains.
    function applyColors(fileContent: string): void {
        let palette;
        try {
            palette = JSON.parse(fileContent);
        } catch (e) {
            console.warn("MaterialThemeLoader: failed to parse colors.json —", e);
            return;
        }

        // Walk every key in the parsed palette and assign to Appearance.m3colors.
        // The bracket-notation assignment works because m3colors properties are
        // plain (non-readonly) since Phase 2 of the adaptive-color implementation.
        for (const snakeKey in palette) {
            const camelKey = snakeKey.replace(/_([a-z])/g, (g) => g[1].toUpperCase());
            const m3Key = `m3${camelKey}`;
            Appearance.m3colors[m3Key] = palette[snakeKey];
        }
    }

    // ===========================================================================
    // Internal implementation
    // ===========================================================================

    // Watches colors.json on disk. Qt.resolvedUrl() adds the "file://" scheme
    // required by FileView while filePath stores the bare absolute path used
    // by the shell script and Directories.
    FileView {
        id: themeFileView
        path: Qt.resolvedUrl(root.filePath)
        watchChanges: true

        // When the file is modified on disk, reload it and arm the debounce
        // timer. Reading immediately on onFileChanged risks catching a partial
        // write while matugen is still flushing — the timer prevents that.
        onFileChanged: {
            themeFileView.reload();
            delayedFileRead.restart();
        }

        // onLoadedChanged fires once after the initial load (and after each
        // explicit reload()). Apply colors as soon as the content is available.
        onLoadedChanged: {
            if (themeFileView.loaded) {
                root.applyColors(themeFileView.text());
            }
        }

        onLoadFailed: {
            console.warn("MaterialThemeLoader: colors.json not found, using default palette");
        }
    }

    // Debounce timer: wait 100 ms after a file-change event before reading,
    // so we never catch matugen mid-write.
    Timer {
        id: delayedFileRead
        interval: 100
        repeat: false

        onTriggered: {
            root.applyColors(themeFileView.text());
        }
    }
}
