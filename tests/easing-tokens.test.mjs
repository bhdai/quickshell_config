import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import test from "node:test";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const appearance = path.join(repoRoot, "modules", "common", "Appearance.qml");

// The values #29 froze; a token whose curve drifts from these silently retimes the button layer.
const tokens = {
    expressiveEffects: [0.34, 0.8, 0.34, 1, 1, 1],
    expressiveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1],
};

function readTokenCurve(source, name) {
    const declaration = source.match(
        new RegExp(`property\\s+var\\s+${name}:\\s*\\[([^\\]]*)\\]`),
    );
    assert.ok(declaration, `Appearance.animation.${name} is not declared`);
    return declaration[1].split(",").map(Number);
}

function qmlFiles() {
    return readdirSync(repoRoot, { recursive: true, withFileTypes: true })
        .filter(entry => entry.isFile() && entry.name.endsWith(".qml"))
        .map(entry => path.join(entry.parentPath, entry.name));
}

test("Appearance.animation carries both expressive easing tokens", () => {
    const source = readFileSync(appearance, "utf8");
    for (const [name, curve] of Object.entries(tokens)) {
        assert.deepEqual(readTokenCurve(source, name), curve);
    }
});

test("no QML file inlines a token curve as a literal", () => {
    const offenders = [];

    for (const file of qmlFiles()) {
        if (file === appearance)
            continue;

        readFileSync(file, "utf8").split("\n").forEach((line, index) => {
            const literal = line.match(/easing\.bezierCurve:\s*\[([^\]]*)\]/);
            if (!literal)
                return;

            const curve = literal[1].split(",").map(Number);
            const name = Object.keys(tokens).find(token => {
                const expected = tokens[token];
                return curve.length === expected.length && curve.every((value, i) => value === expected[i]);
            });
            if (name)
                offenders.push(`${path.relative(repoRoot, file)}:${index + 1} should use Appearance.animation.${name}`);
        });
    }

    assert.deepEqual(offenders, []);
});
