import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";

export function read(...segments) {
    return readFileSync(path.join(...segments), "utf8");
}

// The root type is the first `Type {` that is not part of an import or a comment; every QML
// file in this repo declares it on its own line after the imports.
export function rootType(source) {
    const declaration = source.match(/^([A-Z]\w*)\s*\{/m);
    assert.ok(declaration, "no root type found");
    return declaration[1];
}

// Every `<header> { … }` block in the source, brace-balanced, so a test can ask what a block
// contains without depending on indentation or on where in the file it sits. The header is any
// literal preceding the brace — a QML type name, or a JavaScript function signature.
export function blocks(source, header) {
    const found = [];
    for (let start = source.indexOf(`${header} {`); start !== -1; start = source.indexOf(`${header} {`, start + 1)) {
        let depth = 0;
        for (let i = source.indexOf("{", start); i < source.length; ++i) {
            if (source[i] === "{")
                depth++;
            else if (source[i] === "}" && --depth === 0) {
                found.push(source.slice(start, i + 1));
                break;
            }
        }
    }
    return found;
}
