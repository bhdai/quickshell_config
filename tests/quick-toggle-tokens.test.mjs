import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const quickToggles = path.join(repoRoot, "modules", "controlCenter", "quickToggles");

// QuickToggleButton itself plus everything deriving from it. Long tiles live in the same
// directory but answer to #33, so they are found by root type rather than by a name list.
function quickToggleFiles() {
    return readdirSync(quickToggles)
        .filter(name => name.endsWith(".qml"))
        .map(name => path.join(quickToggles, name))
        .filter(file => {
            if (path.basename(file) === "QuickToggleButton.qml")
                return true;
            return /^QuickToggleButton\s*\{/m.test(readFileSync(file, "utf8"));
        });
}

test("every quick toggle derives from QuickToggleButton", () => {
    assert.deepEqual(
        quickToggleFiles().map(file => path.basename(file, ".qml")).sort(),
        [
            "CloudflareWarp",
            "GameMode",
            "IdleInhibitor",
            "MicToggle",
            "PowerProfile",
            "QuickToggleButton",
            "SilentNotification",
        ],
    );
});

test("no quick toggle reaches into raw m3colors for its foreground", () => {
    const offenders = [];

    for (const file of quickToggleFiles()) {
        readFileSync(file, "utf8").split("\n").forEach((line, index) => {
            if (line.includes("Appearance.m3colors."))
                offenders.push(`${path.relative(repoRoot, file)}:${index + 1}`);
        });
    }

    assert.deepEqual(offenders, []);
});

test("the toggled foreground is colOnPrimary and is declared once", () => {
    const declarations = quickToggleFiles().filter(file =>
        readFileSync(file, "utf8").includes("Appearance.colors.colOnPrimary"),
    );

    assert.deepEqual(declarations.map(file => path.basename(file)), ["QuickToggleButton.qml"]);
});
