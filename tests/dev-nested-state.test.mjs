import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { read } from "./qml-source.mjs";

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const script = read(repoRoot, "scripts", "dev-nested.sh");

test("nested development gives Quickshell isolated XDG state", () => {
    assert.match(script, /NESTED_STATE="\$WORK\/state"/);
    assert.match(script, /XDG_STATE_HOME="\$NESTED_STATE" qs -p "\$CONFIG"/);
});
