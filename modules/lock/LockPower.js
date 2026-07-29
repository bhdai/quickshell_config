.pragma library

/**
 * What a press on a lock-screen power control does, and how the control reads while it is
 * waiting for a confirming press.
 *
 * Extracted for the same reason the reveal rules are: there is no display to check it on,
 * and the interesting cases are the ones nobody clicks through by hand — arming shutdown
 * and then reaching for restart, or pressing suspend while something else is armed. Each
 * of those either takes the machine down or fails to, behind a locked screen.
 *
 * The confirm exists for unsaved work, not for security. None of this is a gate: a local
 * attacker can already hold the physical power button.
 */

var Action = {
    Suspend: "suspend",
    Reboot: "reboot",
    PowerOff: "poweroff"
};

// Display order, left to right: least destructive first, so the pointer travels toward the
// consequences rather than past them.
var Actions = [Action.Suspend, Action.Reboot, Action.PowerOff];

function requiresConfirmation(action) {
    return action !== Action.Suspend;
}

/**
 * @param action the control that was pressed
 * @param pending the action currently awaiting confirmation, "" if none
 * @returns {{pending: string, invoke: string}} the new awaiting-confirmation action, and
 *          the action to run now — "" for neither
 */
function press(action, pending) {
    // The confirming press has to land on the control that asked for it. A press on a
    // sibling moves the confirm there, so backing out of one destructive action by
    // reaching for another never fires the one being backed out of.
    if (!requiresConfirmation(action) || pending === action)
        return {
            pending: "",
            invoke: action
        };

    return {
        pending: action,
        invoke: ""
    };
}

function symbol(action) {
    switch (action) {
    case Action.Suspend:
        return "dark_mode";
    case Action.Reboot:
        return "restart_alt";
    case Action.PowerOff:
        return "power_settings_new";
    default:
        return "";
    }
}

/**
 * @param action the control being labelled
 * @param pending the action currently awaiting confirmation, "" if none
 */
function label(action, pending) {
    if (action === pending)
        return "Confirm";

    switch (action) {
    case Action.Suspend:
        return "Suspend";
    case Action.Reboot:
        return "Restart";
    case Action.PowerOff:
        return "Shut down";
    default:
        return "";
    }
}
