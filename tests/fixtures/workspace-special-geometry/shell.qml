import Quickshell
import QtQuick
import qs.modules.bar

/**
 * Builds the workspace indicator offscreen and measures its width with a special raised and
 * with none.
 *
 * The claim under test is that the special treatment costs zero horizontal pixels: the
 * overlay is a sibling drawn over the row, so the widget's own bounds must not move when one
 * appears. A source assertion can say `implicitWidth` binds to `contentWidth`; only building
 * the thing can say that nothing else in the tree pushed it wider.
 *
 * The blur is deliberately left running for a beat before the measurement rather than
 * measured and torn down, because the second thing this catches is a `MultiEffect` failing
 * over a live, animating subtree. What it cannot catch is how any of it looks — an offscreen
 * grab drops masked and effect-backed drawing, so this asserts geometry and never pixels.
 */
ShellRoot {
    FloatingWindow {
        id: window

        implicitWidth: 400
        implicitHeight: 100
        visible: true

        WorkspaceIndicator {
            id: indicator

            // Held off the origin on purpose. The offscreen platform parks a synthetic
            // cursor at 0,0, and a widget sitting under it reads as permanently hovered —
            // which is the peek, and would suppress the very blur being measured.
            x: 200
            y: 40
            screen: window.screen
        }

        property real restingWidth: 0

        // No Hyprland to answer for the monitor here, so the row rests at its five-slot
        // floor and the active pill has nowhere to point. That is the geometry being
        // compared against, not a claim about what a real session shows.
        Timer {
            interval: 400
            running: true
            onTriggered: {
                window.restingWidth = indicator.implicitWidth;
                // Written straight onto the property the `activespecial` handler writes,
                // which is the whole reason visibility is one string on this widget.
                indicator.specialName = "special";
                blurred.start();
            }
        }

        // Long enough for the 200 ms reveal to finish, so the row is measured with the
        // effect fully engaged rather than mid-transition.
        Timer {
            id: blurred

            interval: 500
            onTriggered: {
                console.log(`RESTING ${Math.round(window.restingWidth)}`);
                console.log(`RAISED ${Math.round(indicator.implicitWidth)}`);
                console.log(`REVEAL ${indicator.specialReveal}`);
                Qt.quit();
            }
        }
    }
}
