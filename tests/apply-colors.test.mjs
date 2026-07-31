import assert from "node:assert/strict";
import {
    chmodSync,
    mkdtempSync,
    mkdirSync,
    readFileSync,
    rmSync,
    writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import test from "node:test";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const script = path.join(repoRoot, "scripts", "colors", "apply-colors.sh");

test("the colour script owns its matugen configuration under XDG state", t => {
    const root = mkdtempSync(path.join(tmpdir(), "apply-colors-"));
    t.after(() => rmSync(root, { recursive: true, force: true }));
    const bin = path.join(root, "bin");
    const state = path.join(root, "state");
    const config = path.join(root, "config");
    const image = path.join(root, "wallpaper.png");
    const calls = path.join(root, "matugen-calls");
    mkdirSync(bin);
    mkdirSync(config);
    writeFileSync(image, "fixture");
    writeFileSync(path.join(config, "sentinel"), "unchanged");

    const fakeMatugen = path.join(bin, "matugen");
    writeFileSync(fakeMatugen, `#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "$*" >"\${MATUGEN_CALLS:?}"
mkdir -p "\${XDG_STATE_HOME:?}/quickshell/user/generated"
printf '{}\\n' >"\${XDG_STATE_HOME}/quickshell/user/generated/colors.json"
`);
    chmodSync(fakeMatugen, 0o755);

    const result = spawnSync(script, [image], {
        encoding: "utf8",
        env: {
            ...process.env,
            PATH: `${bin}:${process.env.PATH}`,
            XDG_CONFIG_HOME: config,
            XDG_STATE_HOME: state,
            MATUGEN_CALLS: calls,
        },
    });

    assert.equal(result.status, 0, result.stderr);
    const ownedRoot = path.join(state, "quickshell", "user");
    const ownedConfig = path.join(ownedRoot, "matugen", "config.toml");
    const ownedTemplate = path.join(ownedRoot, "matugen", "templates", "colors.json");
    assert.equal(readFileSync(path.join(config, "sentinel"), "utf8"), "unchanged");
    assert.match(readFileSync(calls, "utf8"), new RegExp(
        `^image ${image} --mode dark --source-color-index 0 --config ${ownedConfig}\\n$`
    ));
    assert.match(readFileSync(ownedConfig, "utf8"), new RegExp(ownedTemplate));
    assert.match(readFileSync(ownedConfig, "utf8"), new RegExp(
        path.join(ownedRoot, "generated", "colors.json")
    ));
});
