#!/usr/bin/env bash
#
# apply-colors.sh — Generate a Material 3 color palette from a wallpaper image.
#
# Usage:
#   apply-colors.sh <wallpaper-image-path>
#
# Arguments:
#   wallpaper-image-path    Path to a wallpaper image file (jpg, png, etc.)
#
# Exit codes:
#   0    Success — colors.json written
#   1    Error — missing argument, matugen not found, or generation failed
#
# On first run (or when ~/.config/matugen/config.toml is absent), this script
# bootstraps the matugen configuration and installs the quickshell colors
# template. On subsequent runs it checks whether the [templates.m3colors]
# section is already present and appends it if not.
#
# The generated palette is written to:
#   $XDG_STATE_HOME/quickshell/user/generated/colors.json
# (Typically ~/.local/state/quickshell/user/generated/colors.json)

set -euo pipefail

# ==============================================================================
# Constants
# ==============================================================================

MATUGEN_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/matugen"
MATUGEN_CONFIG_FILE="$MATUGEN_CONFIG_DIR/config.toml"
MATUGEN_TEMPLATE_DIR="$MATUGEN_CONFIG_DIR/templates"
MATUGEN_TEMPLATE_FILE="$MATUGEN_TEMPLATE_DIR/colors.json"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
OUTPUT_DIR="$STATE_DIR/quickshell/user/generated"
OUTPUT_FILE="$OUTPUT_DIR/colors.json"

# ==============================================================================
# Argument validation
# ==============================================================================

if [[ $# -eq 0 ]]; then
    echo "Error: no wallpaper image path provided." >&2
    echo "" >&2
    echo "Usage: apply-colors.sh <wallpaper-image-path>" >&2
    exit 1
fi

WALLPAPER="$1"

if [[ ! -f "$WALLPAPER" ]]; then
    echo "Error: '$WALLPAPER' is not a readable file." >&2
    exit 1
fi

# ==============================================================================
# Dependency check
# ==============================================================================

if ! command -v matugen > /dev/null 2>&1; then
    echo "Error: matugen is not installed or not in PATH." >&2
    echo "" >&2
    echo "Install it with one of:" >&2
    echo "  cargo install matugen" >&2
    echo "  nix run nixpkgs#matugen" >&2
    echo "  or see: https://github.com/InioX/matugen" >&2
    exit 1
fi

# ==============================================================================
# Matugen template content
# ==============================================================================
#
# This is the mustache template that matugen uses to produce colors.json.
# It maps every Material 3 color slot to {{colors.<name>.default.hex}}.
# The content is identical to the reference at:
#   docs/popular_projects/dots-hyprland/dots/.config/matugen/templates/colors.json

TEMPLATE_CONTENT='{
  "background": "{{colors.background.default.hex}}",
  "error": "{{colors.error.default.hex}}",
  "error_container": "{{colors.error_container.default.hex}}",
  "inverse_on_surface": "{{colors.inverse_on_surface.default.hex}}",
  "inverse_primary": "{{colors.inverse_primary.default.hex}}",
  "inverse_surface": "{{colors.inverse_surface.default.hex}}",
  "on_background": "{{colors.on_background.default.hex}}",
  "on_error": "{{colors.on_error.default.hex}}",
  "on_error_container": "{{colors.on_error_container.default.hex}}",
  "on_primary": "{{colors.on_primary.default.hex}}",
  "on_primary_container": "{{colors.on_primary_container.default.hex}}",
  "on_primary_fixed": "{{colors.on_primary_fixed.default.hex}}",
  "on_primary_fixed_variant": "{{colors.on_primary_fixed_variant.default.hex}}",
  "on_secondary": "{{colors.on_secondary.default.hex}}",
  "on_secondary_container": "{{colors.on_secondary_container.default.hex}}",
  "on_secondary_fixed": "{{colors.on_secondary_fixed.default.hex}}",
  "on_secondary_fixed_variant": "{{colors.on_secondary_fixed_variant.default.hex}}",
  "on_surface": "{{colors.on_surface.default.hex}}",
  "on_surface_variant": "{{colors.on_surface_variant.default.hex}}",
  "on_tertiary": "{{colors.on_tertiary.default.hex}}",
  "on_tertiary_container": "{{colors.on_tertiary_container.default.hex}}",
  "on_tertiary_fixed": "{{colors.on_tertiary_fixed.default.hex}}",
  "on_tertiary_fixed_variant": "{{colors.on_tertiary_fixed_variant.default.hex}}",
  "outline": "{{colors.outline.default.hex}}",
  "outline_variant": "{{colors.outline_variant.default.hex}}",
  "primary": "{{colors.primary.default.hex}}",
  "primary_container": "{{colors.primary_container.default.hex}}",
  "primary_fixed": "{{colors.primary_fixed.default.hex}}",
  "primary_fixed_dim": "{{colors.primary_fixed_dim.default.hex}}",
  "scrim": "{{colors.scrim.default.hex}}",
  "secondary": "{{colors.secondary.default.hex}}",
  "secondary_container": "{{colors.secondary_container.default.hex}}",
  "secondary_fixed": "{{colors.secondary_fixed.default.hex}}",
  "secondary_fixed_dim": "{{colors.secondary_fixed_dim.default.hex}}",
  "shadow": "{{colors.shadow.default.hex}}",
  "surface": "{{colors.surface.default.hex}}",
  "surface_bright": "{{colors.surface_bright.default.hex}}",
  "surface_container": "{{colors.surface_container.default.hex}}",
  "surface_container_high": "{{colors.surface_container_high.default.hex}}",
  "surface_container_highest": "{{colors.surface_container_highest.default.hex}}",
  "surface_container_low": "{{colors.surface_container_low.default.hex}}",
  "surface_container_lowest": "{{colors.surface_container_lowest.default.hex}}",
  "surface_dim": "{{colors.surface_dim.default.hex}}",
  "surface_tint": "{{colors.surface_tint.default.hex}}",
  "surface_variant": "{{colors.surface_variant.default.hex}}",
  "tertiary": "{{colors.tertiary.default.hex}}",
  "tertiary_container": "{{colors.tertiary_container.default.hex}}",
  "tertiary_fixed": "{{colors.tertiary_fixed.default.hex}}",
  "tertiary_fixed_dim": "{{colors.tertiary_fixed_dim.default.hex}}"
}'

# ==============================================================================
# Bootstrap matugen configuration
# ==============================================================================
#
# The [templates.m3colors] section tells matugen where to read the template
# and where to write the rendered output. We create it on first run and
# append it if the config file exists without that section.

bootstrap_matugen_config() {
    # Create template dir unconditionally — mkdir -p is idempotent.
    mkdir -p "$MATUGEN_TEMPLATE_DIR"

    # Always (re)write the template so it stays in sync with this script.
    printf '%s\n' "$TEMPLATE_CONTENT" > "$MATUGEN_TEMPLATE_FILE"

    if [[ ! -f "$MATUGEN_CONFIG_FILE" ]]; then
        # First-time setup: write a complete, minimal config.toml.
        echo "First-time setup: creating matugen configuration at $MATUGEN_CONFIG_FILE"
        cat > "$MATUGEN_CONFIG_FILE" << 'EOF'
[config]
version_check = false

[templates.m3colors]
input_path = '~/.config/matugen/templates/colors.json'
output_path = '~/.local/state/quickshell/user/generated/colors.json'
EOF
    elif ! grep -qF '[templates.m3colors]' "$MATUGEN_CONFIG_FILE"; then
        # Config exists but is missing the m3colors section — append it.
        echo "Appending [templates.m3colors] to existing $MATUGEN_CONFIG_FILE"
        cat >> "$MATUGEN_CONFIG_FILE" << 'EOF'

[templates.m3colors]
input_path = '~/.config/matugen/templates/colors.json'
output_path = '~/.local/state/quickshell/user/generated/colors.json'
EOF
    fi
}

bootstrap_matugen_config

# ==============================================================================
# Ensure output directory exists
# ==============================================================================

mkdir -p "$OUTPUT_DIR"

# ==============================================================================
# Run matugen to generate the palette
# ==============================================================================

echo "Generating Material 3 palette from: $WALLPAPER"
matugen image "$WALLPAPER" --mode dark

# ==============================================================================
# Verify output was written
# ==============================================================================
#
# matugen does not always exit non-zero on template errors, so we explicitly
# check that the output file exists and is non-empty.

if [[ ! -s "$OUTPUT_FILE" ]]; then
    echo "Error: matugen ran but '$OUTPUT_FILE' was not written or is empty." >&2
    echo "Check your matugen config at $MATUGEN_CONFIG_FILE" >&2
    exit 1
fi

echo "Success: palette written to $OUTPUT_FILE"
