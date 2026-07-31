.pragma library

const SUPPORTED_EXTENSIONS = [".jpg", ".jpeg", ".png", ".bmp"];
const NAME_FILTERS = SUPPORTED_EXTENSIONS.map(extension => `*${extension}`);

function hasSupportedExtension(path) {
    if (typeof path !== "string")
        return false;

    const lower = path.toLowerCase();
    return SUPPORTED_EXTENSIONS.some(extension => lower.endsWith(extension));
}

function forMonitor(globalPath, monitorWallpapers, monitorName) {
    return monitorWallpapers?.[monitorName] || globalPath || "";
}

function cyclePath(paths, currentPath, direction) {
    if (paths.length === 0)
        return "";

    const currentIndex = paths.indexOf(currentPath);
    if (currentIndex === -1)
        return direction < 0 ? paths[paths.length - 1] : paths[0];

    const nextIndex = (currentIndex + direction + paths.length) % paths.length;
    return paths[nextIndex];
}
