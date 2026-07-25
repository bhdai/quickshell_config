import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const quickToggles = path.join(repoRoot, "modules", "controlCenter", "quickToggles");
const longTileNames = ["LongToggleTile", "NetworkToggle", "BluetoothToggle"];

function read(...segments) {
    return readFileSync(path.join(...segments), "utf8");
}

function qmlFiles() {
    return readdirSync(repoRoot, { recursive: true, withFileTypes: true })
        .filter(entry => entry.isFile() && entry.name.endsWith(".qml"))
        .map(entry => path.join(entry.parentPath, entry.name));
}

// The root type is the first `Type {` that is not part of an import or a comment; every QML
// file in this repo declares it on its own line after the imports.
function rootType(source) {
    const declaration = source.match(/^([A-Z]\w*)\s*\{/m);
    assert.ok(declaration, "no root type found");
    return declaration[1];
}

// Every `Type { … }` block in the source, brace-balanced, so a test can ask what a block
// contains without depending on indentation or on where in the file it sits.
function blocks(source, type) {
    const found = [];
    for (let start = source.indexOf(`${type} {`); start !== -1; start = source.indexOf(`${type} {`, start + 1)) {
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

test("BigToggleButton is gone and nothing references it", () => {
    assert.equal(existsSync(path.join(quickToggles, "BigToggleButton.qml")), false);

    const referrers = qmlFiles().filter(file => readFileSync(file, "utf8").includes("BigToggleButton"));
    assert.deepEqual(referrers.map(file => path.relative(repoRoot, file)), []);
});

test("LongToggleTile extends GroupButton and exposes the split targets", () => {
    const source = read(quickToggles, "LongToggleTile.qml");

    assert.equal(rootType(source), "GroupButton");
    assert.match(source, /signal\s+iconClicked/);
    assert.match(source, /signal\s+bodyClicked/);
});

test("the long tiles are LongToggleTiles wired to the split targets", () => {
    for (const name of ["NetworkToggle", "BluetoothToggle"]) {
        const source = read(quickToggles, `${name}.qml`);

        assert.equal(rootType(source), "LongToggleTile", `${name} root type`);
        assert.match(source, /onIconClicked:/, `${name} handles onIconClicked`);
        assert.match(source, /onBodyClicked:/, `${name} handles onBodyClicked`);
        assert.doesNotMatch(source, /onLeftClicked:|onRightClicked:/, `${name} drops the old split`);
    }
});

test("no long tile reaches into raw m3colors, and colOnPrimary is declared once", () => {
    const offenders = [];
    const declarations = [];

    for (const name of longTileNames) {
        const source = read(quickToggles, `${name}.qml`);
        source.split("\n").forEach((line, index) => {
            if (line.includes("Appearance.m3colors."))
                offenders.push(`${name}.qml:${index + 1}`);
        });
        if (source.includes("Appearance.colors.colOnPrimary"))
            declarations.push(`${name}.qml`);
    }

    assert.deepEqual(offenders, []);
    assert.deepEqual(declarations, ["LongToggleTile.qml"]);
});

test("the long-tile row is a ButtonGroup", () => {
    const source = read(repoRoot, "modules", "controlCenter", "ControlCenterContent.qml");
    const rows = blocks(source, "ButtonGroup").filter(body => /NetworkToggle\s*\{/.test(body));

    assert.equal(rows.length, 1, "the Wi-Fi tile sits in exactly one ButtonGroup");
    assert.match(rows[0], /BluetoothToggle\s*\{/);
});
