import Quickshell
import QtQuick
import qs.modules.dashboard

ShellRoot {
    FloatingWindow {
        id: window

        readonly property string scenario: Quickshell.env("DASHBOARD_TRANSITION_SCENARIO") ?? ""
        property string phase: ""
        property real trackStart: 0
        property real indicatorStart: 0
        property real indicatorTarget: 0
        property bool sampledInFlight: false

        implicitWidth: 1000
        implicitHeight: 700
        visible: true

        DashboardCard {
            id: card
            tabs: [
                { key: "dashboard", label: "Dashboard", icon: "dashboard" },
                { key: "wallpaper", label: "Wallpaper", icon: "wallpaper" },
                { key: "performance", label: "Performance", icon: "speed" }
            ]
            currentTab: "dashboard"
        }

        function near(first: real, second: real): bool {
            return Math.abs(first - second) <= 0.5;
        }

        function residents(): string {
            return card.residentDestinationKeys.join(",");
        }

        function fail(message: string): void {
            console.log(`MOTION FAIL ${message}`);
            Qt.quit();
        }

        function settled(): bool {
            return !card.transitionMotionRunning
                && window.near(card.transitionTrackPosition, card.targetTrackPosition);
        }

        function finish(label: string): void {
            Qt.callLater(() => {
                if (!window.sampledInFlight) {
                    window.fail(`${label} never exposed an in-flight sample`);
                    return;
                }
                if (!window.near(card.indicatorItem.x, card.indicatorItem.targetX)) {
                    window.fail(`${label} indicator did not settle with the track`);
                    return;
                }
                if (window.residents() !== "performance") {
                    window.fail(`${label} did not prune residency: ${window.residents()}`);
                    return;
                }

                console.log(`MOTION ${label} settled card=${card.width}x${card.height} actual=${card.transitionTrackPosition} target=${card.targetTrackPosition} residents=${window.residents()}`);
                Qt.quit();
            });
        }

        Timer {
            interval: 50
            running: true
            onTriggered: {
                if (window.residents() !== "dashboard") {
                    window.fail(`the resting card loaded more than its selected pane: ${window.residents()}`);
                    return;
                }
                window.trackStart = card.transitionTrackPosition;
                window.indicatorStart = card.indicatorItem.x;

                if (window.scenario === "skip") {
                    window.phase = "skip";
                    card.currentTab = "performance";
                    window.indicatorTarget = card.indicatorItem.targetX;
                    if (!window.near(card.transitionTrackPosition, window.trackStart)) {
                        window.fail("the skip moved before its corridor was observable");
                        return;
                    }
                    if (window.residents() !== "dashboard,wallpaper,performance") {
                        window.fail(`the skip corridor was not instantiated: ${window.residents()}`);
                        return;
                    }
                    console.log(`MOTION SKIP prepared residents=${window.residents()} actual=${card.transitionTrackPosition} target=${card.targetTrackPosition}`);
                } else if (window.scenario === "retarget") {
                    window.phase = "wallpaper";
                    card.currentTab = "wallpaper";
                    window.indicatorTarget = card.indicatorItem.targetX;
                    if (!window.near(card.transitionTrackPosition, window.trackStart)) {
                        window.fail("the first move began before its corridor was observable");
                        return;
                    }
                    if (window.residents() !== "dashboard,wallpaper") {
                        window.fail(`the first corridor was not instantiated: ${window.residents()}`);
                        return;
                    }
                    console.log(`MOTION RETARGET prepared residents=${window.residents()} actual=${card.transitionTrackPosition} target=${card.targetTrackPosition}`);
                } else {
                    window.fail(`unknown scenario: ${window.scenario}`);
                    return;
                }

                sample.start();
            }
        }

        Timer {
            id: sample
            interval: 1
            repeat: true
            onTriggered: {
                const track = card.transitionTrackPosition;
                const target = card.targetTrackPosition;
                const indicator = card.indicatorItem.x;

                if (window.phase === "skip") {
                    if (!window.sampledInFlight && !window.near(track, window.trackStart) && !window.near(track, target)) {
                        if (window.near(indicator, window.indicatorStart) || window.near(indicator, window.indicatorTarget)) {
                            window.fail(`the indicator was at an endpoint while the skip track was in flight: track=${track} indicator=${indicator}`);
                            return;
                        }
                        window.sampledInFlight = true;
                        console.log(`MOTION SKIP inflight residents=${window.residents()}`);
                    }
                    if (window.settled()) {
                        sample.stop();
                        window.finish("SKIP");
                    }
                    return;
                }

                if (window.phase === "wallpaper" && !window.near(track, window.trackStart) && !window.near(track, target)) {
                    if (window.near(indicator, window.indicatorStart) || window.near(indicator, window.indicatorTarget)) {
                        window.fail(`the indicator was at an endpoint while the first track was in flight: track=${track} indicator=${indicator}`);
                        return;
                    }
                    if (window.near(card.width, 896) || window.near(card.width, 700)) {
                        window.fail(`the card width was at an endpoint while the track was in flight: width=${card.width}`);
                        return;
                    }

                    window.trackStart = track;
                    window.indicatorStart = indicator;
                    const cardWidth = card.width;
                    card.currentTab = "performance";
                    window.indicatorTarget = card.indicatorItem.targetX;
                    if (!window.near(card.transitionTrackPosition, window.trackStart)) {
                        window.fail("retargeting restarted the track instead of continuing from its current position");
                        return;
                    }
                    if (!window.near(card.width, cardWidth)) {
                        window.fail("retargeting jumped the card instead of continuing from its current size");
                        return;
                    }
                    if (window.residents() !== "dashboard,wallpaper,performance") {
                        window.fail(`retargeting was not monotonic: ${window.residents()}`);
                        return;
                    }
                    if (card.targetTrackPosition !== -1548) {
                        window.fail(`the new corridor was not resident before retargeting: target=${card.targetTrackPosition}`);
                        return;
                    }

                    window.phase = "performance";
                    console.log(`MOTION RETARGET redirected residents=${window.residents()} target=${card.targetTrackPosition}`);
                    return;
                }

                if (window.phase === "performance") {
                    if (!window.settled() && window.residents() !== "dashboard,wallpaper,performance") {
                        window.fail(`residency shrank during the retarget: ${window.residents()}`);
                        return;
                    }
                    if (!window.sampledInFlight && !window.near(track, window.trackStart) && !window.near(track, target)) {
                        if (window.near(indicator, window.indicatorStart) || window.near(indicator, window.indicatorTarget)) {
                            window.fail(`the indicator was at an endpoint while the retargeted track was in flight: track=${track} indicator=${indicator}`);
                            return;
                        }
                        window.sampledInFlight = true;
                        console.log(`MOTION RETARGET inflight residents=${window.residents()}`);
                    }
                    if (window.settled()) {
                        sample.stop();
                        window.finish("RETARGET");
                    }
                }
            }
        }
    }
}
