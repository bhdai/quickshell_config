import assert from "node:assert/strict";
import path from "node:path";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";
import { blocks, read } from "./qml-source.mjs";

const { Action, Actions, requiresConfirmation, press, symbol, iconSource, label } = loadQmlJs(
    new URL("../modules/lock/LockPower.js", import.meta.url),
    ["Action", "Actions", "requiresConfirmation", "press", "symbol", "iconSource", "label"],
);

const repoRoot = path.dirname(path.dirname(new URL(import.meta.url).pathname));
const lockDir = path.join(repoRoot, "modules", "lock");

const controls = read(lockDir, "LockPowerControls.qml");
const surface = read(lockDir, "LockSurface.qml");

function withoutComments(source) {
    return source.replace(/\/\*[\s\S]*?\*\//g, "").replace(/\/\/.*$/gm, "");
}

test("the three actions the lock screen offers, and no others", () => {
    assert.deepEqual(Actions, [Action.Suspend, Action.Reboot, Action.PowerOff]);
});

// Suspending before closing the lid is the case the whole feature exists for, and a
// confirm step would cost exactly that.
test("suspend fires on the first press", () => {
    assert.equal(requiresConfirmation(Action.Suspend), false);
    assert.deepEqual(press(Action.Suspend, ""), { pending: "", invoke: Action.Suspend });
});

// The confirm guards unsaved work, not the lock: an attacker can already hold the power
// button. One stray click must not take the machine down with it.
test("restart and shutdown arm rather than fire on the first press", () => {
    assert.equal(requiresConfirmation(Action.Reboot), true);
    assert.equal(requiresConfirmation(Action.PowerOff), true);

    assert.deepEqual(press(Action.Reboot, ""), { pending: Action.Reboot, invoke: "" });
    assert.deepEqual(press(Action.PowerOff, ""), { pending: Action.PowerOff, invoke: "" });
});

test("pressing the armed control a second time fires it and disarms", () => {
    assert.deepEqual(press(Action.Reboot, Action.Reboot), { pending: "", invoke: Action.Reboot });
    assert.deepEqual(press(Action.PowerOff, Action.PowerOff), { pending: "", invoke: Action.PowerOff });
});

// The confirming press has to be on the control that asked for it. Otherwise a user who
// armed shutdown and then reached for restart would get the shutdown they were backing out
// of, from a click aimed somewhere else entirely.
test("a press on a different control moves the confirm rather than firing the armed one", () => {
    assert.deepEqual(press(Action.PowerOff, Action.Reboot), { pending: Action.PowerOff, invoke: "" });
    assert.deepEqual(press(Action.Reboot, Action.PowerOff), { pending: Action.Reboot, invoke: "" });
});

test("suspend fires from a first press even while another control is armed, and disarms it", () => {
    assert.deepEqual(press(Action.Suspend, Action.PowerOff), { pending: "", invoke: Action.Suspend });
});

// Restart and shutdown are shipped assets, sleep is an icon-font glyph, and the drawing
// picks between them on exactly this — two answers for one action would draw both.
test("every action has one icon and a resting label", () => {
    for (const action of Actions) {
        assert.notEqual(symbol(action) === "", iconSource(action) === "", `${action} has neither icon or both`);
        assert.notEqual(label(action, ""), "");
    }
});

// The same glyphs the session screen already shows for these three actions, read off that
// screen rather than restated here: a second list would be free to drift.
test("the icons are the session screen's, not a second set", () => {
    const sessionScreen = read(repoRoot, "modules", "sessionScreen", "SessionScreen.qml");

    const iconFor = name => {
        const button = sessionScreen.match(new RegExp(`buttonIcon(Source)?: "([^"]+)"\\s*\\n\\s*buttonText: "${name}"`));
        assert.ok(button, `the session screen has no ${name} button`);
        return button[2];
    };

    assert.equal(symbol(Action.Suspend) || iconSource(Action.Suspend), iconFor("Sleep"));
    assert.equal(symbol(Action.Reboot) || iconSource(Action.Reboot), iconFor("Reboot"));
    assert.equal(symbol(Action.PowerOff) || iconSource(Action.PowerOff), iconFor("Shutdown"));
});

// The armed state has to be readable, or the second press is a guess. An unarmed control
// keeps its own label while a sibling is armed, so only one control is ever asking.
test("only the armed control says it is waiting for a confirming press", () => {
    assert.notEqual(label(Action.PowerOff, Action.PowerOff), label(Action.PowerOff, ""));
    assert.equal(label(Action.Reboot, Action.PowerOff), label(Action.Reboot, ""));
    assert.equal(label(Action.Suspend, Action.PowerOff), label(Action.Suspend, ""));
});

test("the controls are instantiated exactly once in the surface", () => {
    assert.equal(blocks(surface, "LockPowerControls").length, 1);
});

// Unauthenticated is the decision, not an oversight. Nothing here may consult the lock
// state before acting — reading it would be the first step toward gating on it.
test("nothing gates the controls on authentication", () => {
    const code = withoutComments(controls);

    assert.doesNotMatch(code, /Lock\.(secure|lockState|acceptingInput|authenticating|password)/);
});

test("the controls call the session service's existing functions", () => {
    const code = withoutComments(controls);

    assert.match(code, /Session\.suspend\(\)/);
    assert.match(code, /Session\.reboot\(\)/);
    assert.match(code, /Session\.poweroff\(\)/);
});

// A requirement only the lock screen has must not grow the shared session component. The
// consistency comes from the Appearance tokens both draw on, not from a shared type.
test("the controls are lock-owned, built from the shared primitives", () => {
    assert.doesNotMatch(controls, /sessionScreen|SessionActionButton/);
    assert.ok(blocks(controls, "RippleButton").length > 0, "not built from RippleButton");
    assert.ok(blocks(controls, "MaterialSymbol").length > 0, "not built from MaterialSymbol");
    assert.ok(blocks(controls, "CustomIcon").length > 0, "not built from CustomIcon");
});

test("the confirm state is owned by the controls rather than by the lock singleton", () => {
    assert.match(controls, /property string pending/);
    assert.doesNotMatch(read(repoRoot, "services", "Lock.qml"), /\bpending\b/);
});

// Absent at rest, revealing with the authentication area — the resting screen stays quiet,
// and the same reveal state drives both so they cannot diverge.
test("the controls reveal with the authentication area and are absent at rest", () => {
    const [instantiation] = blocks(surface, "LockPowerControls");

    assert.match(instantiation, /opacity:\s*root\.revealed \? 1 : 0/);
    assert.match(instantiation, /visible:\s*opacity > 0/);
});

// Backing out of the prompt has to back out of the arming with it, or a shutdown armed
// and then dismissed would still be armed the next time the screen is revealed.
test("dismissing the authentication area disarms any pending confirm", () => {
    const [instantiation] = blocks(surface, "LockPowerControls");

    assert.match(instantiation, /pending = ""/);
});
