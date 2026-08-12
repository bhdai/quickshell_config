import Quickshell
import QtQuick
import qs.modules.common.widgets

/**
 * Builds the tooltip offscreen and measures it.
 *
 * Two things are being checked that source assertions cannot see. First, that the Material 3
 * metrics survive contact with real font rendering — the plain chip's 24px floor and 200px
 * ceiling, the rich card's 320px ceiling, and the padding around both. Second, that an
 * in-scene tooltip lands where TooltipPlacement says it should once it has a real size to
 * place, including the flip at a window edge.
 *
 * A FloatingWindow rather than the real call sites: a layer surface cannot be built with no
 * Wayland session to build it on, and the popup-surface path is the compositor's placement
 * rather than ours. #96's warning holds — this asserts geometry and never pixels.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 800
        implicitHeight: 400
        visible: true

        TooltipContainer {
            id: plain
            text: "Volume"
        }

        TooltipContainer {
            id: wrapped
            text: "A tray description long enough that it has to wrap inside the plain chip instead of running off the side of the screen"
        }

        TooltipContainer {
            id: rich
            variant: TooltipContainer.Variant.Rich
            subhead: "A track title long enough to need the whole width of a rich tooltip and then some more"
            text: "An artist name"
        }

        TooltipContainer {
            id: richBody
            variant: TooltipContainer.Variant.Rich
            text: "Body with no subhead"
        }

        // Stands in for the battery readout: rows of a fixed size, so the card's size is
        // arithmetic on them and a padding regression is visible as an exact number.
        TooltipContainer {
            id: custom
            variant: TooltipContainer.Variant.Rich
            contentComponent: Component {
                Column {
                    spacing: 10
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 120
                            height: 18
                            color: "transparent"
                        }
                    }
                }
            }
        }

        // Room above and below: the tooltip should take the side it was asked for.
        Item {
            id: middle
            x: 360
            y: 200
            width: 80
            height: 40

            Tooltip {
                id: middleTip
                target: middle
                text: "Centred"
                surface: Tooltip.Surface.InScene
            }
        }

        // Hard against the top of the window, so an "above" tooltip has to flip below.
        Item {
            id: topEdge
            x: 8
            y: 0
            width: 40
            height: 30

            Tooltip {
                id: topTip
                target: topEdge
                text: "Flipped"
                surface: Tooltip.Surface.InScene
            }
        }

        /// The container a Tooltip loaded, found through the Loader it parents into its target.
        function loadedContainer(target: Item): Item {
            for (const child of target.children) {
                if (child.item !== undefined && child.item !== null)
                    return child;
            }
            return null;
        }

        function report(label: string, container: Item): string {
            return `${label} ${Math.round(container.implicitWidth)}x${Math.round(container.implicitHeight)} shadow=${container.shadowMargin}`;
        }

        function measureScene(label: string, target: Item): bool {
            const loader = window.loadedContainer(target);
            if (loader === null) {
                console.log(`SCENE ${label} missing`);
                return false;
            }
            console.log(`SCENE ${label}=${Math.round(loader.x)},${Math.round(loader.y)} ${Math.round(loader.width)}x${Math.round(loader.height)}`);
            return true;
        }

        Timer {
            running: true
            interval: 150
            onTriggered: {
                console.log(window.report("PLAIN", plain));
                console.log(window.report("WRAPPED", wrapped));
                console.log(window.report("RICH", rich));
                console.log(window.report("RICHBODY", richBody));
                console.log(window.report("CUSTOM", custom));
                middleTip.hovered = true;
                centred.start();
            }
        }

        // One tooltip at a time, because that is the rule the component enforces: hovering the
        // second anchor while the first is up makes TooltipManager dismiss the first, and a
        // fixture that raised both would measure one of them empty.
        Timer {
            id: centred
            interval: 150
            onTriggered: {
                window.measureScene("centred", middle);
                middleTip.hovered = false;
                topTip.hovered = true;
                flipped.start();
            }
        }

        Timer {
            id: flipped
            interval: 150
            onTriggered: {
                window.measureScene("flipped", topEdge);
                Qt.quit();
            }
        }
    }
}
