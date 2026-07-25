import assert from "node:assert/strict";
import test from "node:test";

import { loadQmlJs } from "./load-qml-js.mjs";

const { parseConnectionDetails, cidrToNetmask } = loadQmlJs(
    new URL("../services/NetworkParse.js", import.meta.url),
    ["parseConnectionDetails", "cidrToNetmask"],
);

// Verbatim output of the two nmcli calls the service concatenates, for an activated profile.
const CONNECTED = `connection.autoconnect:yes
connection.metered:unknown
GENERAL.DEVICES:wlp0s20f3
GENERAL.STATE:activated
IP4.ADDRESS[1]:172.20.157.187/24
IP4.GATEWAY:172.20.157.54
IP4.DNS[1]:172.20.157.54
IP6.ADDRESS[1]:fe80::1d2a:48a3:50ee:da9e/64

GENERAL.DEVICE:wlp0s20f3
GENERAL.HWADDR:BC:03:58:33:7A:F7

GENERAL.DEVICE:lo
GENERAL.HWADDR:00:00:00:00:00:00
`;

test("an activated profile parses into the subpage's rows", () => {
    assert.deepEqual(parseConnectionDetails(CONNECTED), {
        device: "wlp0s20f3",
        state: "activated",
        autoconnect: true,
        metered: "unknown",
        ipv4: "172.20.157.187",
        netmask: "255.255.255.0",
        gateway: "172.20.157.54",
        dns: ["172.20.157.54"],
        ipv6: "fe80::1d2a:48a3:50ee:da9e",
        mac: "BC:03:58:33:7A:F7",
    });
});

test("the MAC is taken from the connection's own device, not the first one listed", () => {
    const other = `GENERAL.DEVICES:wlp0s20f3

GENERAL.DEVICE:enp0s31f6
GENERAL.HWADDR:AA:BB:CC:DD:EE:FF

GENERAL.DEVICE:wlp0s20f3
GENERAL.HWADDR:11:22:33:44:55:66
`;
    assert.equal(parseConnectionDetails(other).mac, "11:22:33:44:55:66");
});

test("every DNS server is collected in order", () => {
    const multi = `IP4.DNS[1]:1.1.1.1
IP4.DNS[2]:8.8.8.8
IP4.DNS[3]:9.9.9.9
`;
    assert.deepEqual(parseConnectionDetails(multi).dns, ["1.1.1.1", "8.8.8.8", "9.9.9.9"]);
});

test("auto-connect is false unless nmcli says yes", () => {
    assert.equal(parseConnectionDetails("connection.autoconnect:no\n").autoconnect, false);
});

test("a profile with no addresses yet yields empty fields rather than undefined", () => {
    assert.deepEqual(parseConnectionDetails("GENERAL.STATE:activating\n"), {
        device: "",
        state: "activating",
        autoconnect: false,
        metered: "unknown",
        ipv4: "",
        netmask: "",
        gateway: "",
        dns: [],
        ipv6: "",
        mac: "",
    });
});

test("empty output yields empty fields", () => {
    assert.equal(parseConnectionDetails("").ipv4, "");
});

test("cidrToNetmask covers whole and partial octets", () => {
    assert.equal(cidrToNetmask(24), "255.255.255.0");
    assert.equal(cidrToNetmask(16), "255.255.0.0");
    assert.equal(cidrToNetmask(22), "255.255.252.0");
    assert.equal(cidrToNetmask(32), "255.255.255.255");
    assert.equal(cidrToNetmask(0), "0.0.0.0");
});

test("cidrToNetmask rejects a prefix that is not a prefix", () => {
    assert.equal(cidrToNetmask(NaN), "");
    assert.equal(cidrToNetmask(33), "");
    assert.equal(cidrToNetmask(-1), "");
});
