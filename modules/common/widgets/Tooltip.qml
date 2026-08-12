import QtQuick
import Quickshell
import qs.modules.common
import "TooltipPlacement.js" as TooltipPlacement

/**
 * A Material 3 tooltip: hover to show, no delay either way, one on screen at a time.
 *
 * Declare it as a child of whatever it describes:
 *
 *     MouseArea {
 *         Tooltip { target: parent; text: "Volume" }
 *     }
 *
 * `target` is what gets hovered and what the tooltip is positioned against; it does not have
 * to be the parent. The tooltip itself is invisible and zero-sized, so it is skipped by
 * layouts and cannot disturb the call site's geometry.
 *
 * Hover is the only trigger. Focus and long-press are deliberately absent: this is a
 * keybind-driven Wayland shell, and a tooltip that any call site can show by hand is a popup
 * with extra steps. Where something genuinely needs the look without hover — the slider's
 * value readout, the session screen's focus label — use `TooltipContainer` directly.
 */
Item {
    id: root

    enum Surface {
        Popup,
        InScene
    }

    enum Side {
        Above,
        Below
    }

    required property Item target
    property string text: ""
    /// Rich only. Setting it does not switch variant — set `variant` too.
    property string subhead: ""
    property int variant: TooltipContainer.Variant.Plain

    /**
     * `Popup` puts the tooltip in its own Wayland surface so it can leave the window that
     * raised it — required for anything in the bar, whose surface it would otherwise be
     * clipped to. `InScene` draws it as an ordinary child of `target`, which is what the
     * slider's tooltip needs so it can follow a dragging handle without re-anchoring a real
     * surface every frame.
     */
    property int surface: Tooltip.Surface.Popup

    /**
     * Material 3 puts plain tooltips above their anchor, except in an app bar where they go
     * below. Bar call sites therefore pass `Below`; everything else takes the default.
     */
    property int side: Tooltip.Side.Above

    /// Named `active` rather than `enabled` so it cannot be mistaken for Item's own property,
    /// which means something else and propagates to children.
    property bool active: true

    // Either string is enough to be worth showing: a rich tooltip may carry only a subhead.
    readonly property bool showing: root.hovered && root.active && (root.text !== "" || root.subhead !== "")
    /// Distance between the anchor's edge and the tooltip's, for an anchor with a boundary.
    readonly property real gap: 4

    property bool hovered: false
    property bool animateEntry: true

    /// Called by TooltipManager when another tooltip takes over.
    function dismiss() {
        root.hovered = false;
    }

    visible: false

    onShowingChanged: {
        if (root.showing)
            root.animateEntry = TooltipManager.claim(root);
        else
            TooltipManager.release(root);
    }

    HoverHandler {
        parent: root.target
        enabled: root.target !== null
        onHoveredChanged: root.hovered = hovered
    }

    Loader {
        id: popupLoader

        active: root.showing && root.surface === Tooltip.Surface.Popup && root.target?.QsWindow?.window !== null

        sourceComponent: PopupWindow {
            id: popup

            visible: true
            color: "transparent"

            // The surface is grown by the shadow's margin on every side so a rich tooltip's
            // elevation has room to draw instead of being clipped at the surface edge.
            implicitWidth: popupContainer.implicitWidth + popupContainer.shadowMargin * 2
            implicitHeight: popupContainer.implicitHeight + popupContainer.shadowMargin * 2

            // Placement here is Quickshell's, not TooltipPlacement.js: the compositor owns
            // this surface's position and already slides and flips it at screen edges, and
            // second-guessing that from inside the client is how tooltips end up on the wrong
            // output. The JS module places the in-scene case below, which has no such help.
            anchor {
                window: root.target.QsWindow.window
                item: root.target
                edges: root.side === Tooltip.Side.Below ? Edges.Bottom : Edges.Top
                gravity: root.side === Tooltip.Side.Below ? Edges.Bottom : Edges.Top
                // The gap is wanted between the anchor and the visible card, but the margin
                // applies to the surface, which extends `shadowMargin` further out. Without
                // the correction a rich tooltip would sit a shadow's width too far away.
                margins.top: root.side === Tooltip.Side.Below ? root.gap - popupContainer.shadowMargin : 0
                margins.bottom: root.side === Tooltip.Side.Above ? root.gap - popupContainer.shadowMargin : 0
            }

            TooltipContainer {
                id: popupContainer
                anchors.centerIn: parent
                variant: root.variant
                text: root.text
                subhead: root.subhead
            }

            TooltipMotion {
                target: popupContainer
                animate: root.animateEntry
            }
        }
    }

    Loader {
        id: sceneLoader

        // Parented to the target rather than to this item, which is invisible — a child of an
        // invisible item does not render.
        parent: root.target
        active: root.showing && root.surface === Tooltip.Surface.InScene
        z: 100

        x: placement.x
        y: placement.y

        readonly property point placement: root.placeInScene(sceneLoader.width, sceneLoader.height)

        sourceComponent: TooltipContainer {
            id: sceneContainer
            variant: root.variant
            text: root.text
            subhead: root.subhead

            TooltipMotion {
                target: sceneContainer
                animate: root.animateEntry
            }
        }
    }

    /**
     * Position for the in-scene surface, in `target`'s coordinates.
     *
     * Bounds are the host window rather than the screen: an in-scene tooltip is clipped by
     * the window it lives in, so that is the edge it has to flip and slide against.
     */
    function placeInScene(width, height) {
        const window = root.target?.Window.window;
        if (!window || width <= 0 || height <= 0)
            return Qt.point(0, 0);

        // Read through so the binding re-evaluates when the target moves or resizes;
        // mapToItem is a plain call and registers no dependency of its own.
        const geometry = [root.target.x, root.target.y, root.target.width, root.target.height];
        const origin = root.target.mapToItem(null, 0, 0);

        const placed = TooltipPlacement.place({
            x: origin.x,
            y: origin.y,
            width: geometry[2],
            height: geometry[3]
        }, {
            width: width,
            height: height
        }, {
            x: 0,
            y: 0,
            width: window.width,
            height: window.height
        }, root.side === Tooltip.Side.Below ? "below" : "above", root.gap);

        return root.target.mapFromItem(null, placed.x, placed.y);
    }
}
