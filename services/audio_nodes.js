.pragma library

// `text` is `pactl -f json list sinks`. A sink is unavailable only when every port it has
// reports "not available" — an unplugged HDMI or jack. "availability unknown" is what a laptop
// speaker reports, so it counts as available. Anything unreadable hides nothing.
function parseSinkAvailability(text) {
    let sinks;
    try {
        sinks = JSON.parse(text);
    } catch (e) {
        return {};
    }
    if (!Array.isArray(sinks))
        return {};
    const out = {};
    for (const sink of sinks) {
        if (!sink || typeof sink.name !== "string")
            continue;
        const ports = Array.isArray(sink.ports) ? sink.ports : [];
        out[sink.name] = ports.length === 0 || ports.some(port => port?.availability !== "not available");
    }
    return out;
}

// PipeWire marks an app's playback stream as a sink too, since it takes audio in from the app.
// Hardware outputs are the sinks that are not streams.
function isOutputDevice(node) {
    return !!node && node.isSink && !node.isStream && !!node.audio;
}

function isAppStream(node) {
    return !!node && node.isSink && node.isStream && !!node.audio;
}

// `availability` is parseSinkAvailability's map. The current output is kept even when it
// reads unplugged, so the picker never hides the device sound is going to.
function listedOutputs(nodes, availability, current) {
    return nodes.filter(node => isOutputDevice(node) && (node === current || availability[node.name] !== false));
}

function outputLabel(node) {
    if (!node)
        return "Unknown output";
    return node.nickname || node.description || node.name || "Unknown output";
}

// Returns a Material Symbols name. `iconName` is the node's `device.icon-name` property, which
// is only readable once the node is bound, so it may be "".
function outputSymbol(node, iconName) {
    const text = [node?.name, node?.nickname, node?.description, iconName].join(" ").toLowerCase();
    if (text.includes("headset"))
        return "headset_mic";
    if (/headphone|earbud|earphone|airpod/.test(text))
        return "headphones";
    if (/hdmi|displayport/.test(text))
        return "tv";
    if (text.includes("bluez") || text.includes("bluetooth"))
        return "bluetooth";
    return "speaker";
}

// `props` is the node's PipeWire properties, {} until the node is bound.
function streamLabel(props, node) {
    return props["application.name"] || node?.description || props["media.name"] || node?.name || "Unknown app";
}

function streamIconName(props) {
    return props["application.icon-name"] || props["application.process.binary"] || "";
}

// List models get these rows rather than the nodes themselves. PipeWire deletes a node outright,
// and a model row holding that QObject is dereferenced unchecked while a delegate is built, which
// crashes the shell; primitives cannot dangle. The name rides along because PipeWire reuses ids,
// so id alone could resolve to whichever node inherited it.
function nodeRows(nodes) {
    return nodes.filter(node => !!node).map(node => ({
        key: `${node.id}:${node.name}`,
        id: node.id,
        name: node.name
    }));
}
