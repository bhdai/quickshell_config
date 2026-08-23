.pragma library

function consume(line, awaitingArgument) {
    if (line.includes("interface=org.freedesktop.login1.Manager") && line.includes("member=PrepareForSleep")) {
        return {
            awaitingArgument: true,
            resumed: false,
        };
    }

    if (!awaitingArgument) {
        return {
            awaitingArgument: false,
            resumed: false,
        };
    }

    const argument = line.match(/^\s*boolean\s+(true|false)\s*$/);
    if (!argument) {
        return {
            awaitingArgument: true,
            resumed: false,
        };
    }

    return {
        awaitingArgument: false,
        resumed: argument[1] === "false",
    };
}
