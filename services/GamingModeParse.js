.pragma library

/**
 * Returns gaming-mode state from Hyprland's blur option, or null for invalid output.
 */
function activeFromBlurOption(text) {
    let option;
    try {
        option = JSON.parse(text);
    } catch (error) {
        return null;
    }

    return typeof option?.bool === "boolean" ? !option.bool : null;
}
