//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

/**
 * PROTOTYPE — throwaway. Answers "The sliding pane transition: a Flickable of all panes,
 * or something narrower": which ownership model still reads as one spatial transition while
 * the dashboard card moves between destination-sized canvases.
 *
 * Run it:  qs -p prototypes/pane-transition
 *
 * The three variants use the real Dashboard and Wallpaper canvas sizes after the settled
 * 64px tab-bar decision. Performance is deliberately a third, different-sized canvas so the
 * transition cannot accidentally depend on either existing destination's geometry.
 *
 * Accepted: variant A. The track is controlled by tab selection only; it exposes neither
 * drag-to-swipe nor wheel-over-tabs, and the old pane fade is removed.
 */
ShellRoot {
    id: shell

    readonly property var panes: [
        {
            name: "Dashboard",
            icon: "dashboard",
            width: 872,
            height: 428,
            detail: "calendar + weather"
        },
        {
            name: "Wallpaper",
            icon: "wallpaper",
            width: 676,
            height: 424,
            detail: "4 × 4 library grid"
        },
        {
            name: "Performance",
            icon: "speed",
            width: 784,
            height: 444,
            detail: "four history cards"
        }
    ]
    readonly property var variants: [
        {
            name: "A — pane track",
            summary: "Accepted — one tab-controlled track; no fade, direct dragging, or wheel cycling."
        },
        {
            name: "B — incoming only",
            summary: "One Loader; the old pane cuts away and the new pane slides in over 200ms."
        },
        {
            name: "C — exit, swap, enter",
            summary: "One Loader; 200ms out, a source swap, then 200ms in."
        }
    ]

    property int variantIndex: 0
    property int selectedIndex: 0
    property real motionScale: 1

    readonly property Item activeCase: [trackCase, incomingCase, sequentialCase][variantIndex]

    function cardWidth(index: int): real {
        return panes[index].width + 24;
    }

    function cardHeight(index: int): real {
        return panes[index].height + 24 + 64 + 8;
    }

    function trackX(index: int): real {
        let x = 0;
        for (let i = 0; i < index; i++)
            x += panes[i].width;
        return x;
    }

    function choosePane(index: int): void {
        if (index === selectedIndex)
            return;
        selectedIndex = index;
        activeCase.select(index);
    }

    function chooseVariant(index: int): void {
        if (index === variantIndex)
            return;
        variantIndex = index;
        Qt.callLater(() => activeCase.reset(selectedIndex));
    }

    FloatingWindow {
        id: window

        implicitWidth: 1080
        implicitHeight: 790
        color: Appearance.colors.colLayer0
        visible: true

        Text {
            id: title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            text: "Sliding pane ownership — drive every variant through differently sized destinations"
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnLayer0
        }

        Text {
            id: question
            anchors.top: title.bottom
            anchors.topMargin: 8
            anchors.left: title.left
            anchors.right: title.right
            text: "Watch the card edge and the pane handoff together. Click rapidly or skip across two tabs; those are the cases that expose who really owns the transition."
            wrapMode: Text.WordWrap
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
        }

        Row {
            id: controls
            anchors.top: question.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Repeater {
                model: shell.panes

                delegate: PillButton {
                    required property int index
                    required property var modelData

                    label: modelData.name
                    selected: shell.selectedIndex === index
                    onClicked: shell.choosePane(index)
                }
            }

            Rectangle {
                width: 1
                height: 32
                color: Appearance.colors.colOutlineVariant
            }

            PillButton {
                label: shell.motionScale === 1 ? "200ms motion" : "600ms inspection"
                selected: shell.motionScale !== 1
                onClicked: shell.motionScale = shell.motionScale === 1 ? 3 : 1
            }
        }

        Rectangle {
            id: stage
            anchors.top: controls.bottom
            anchors.topMargin: 18
            anchors.horizontalCenter: parent.horizontalCenter
            width: 920
            height: 560
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1
            border.width: 1
            border.color: Appearance.colors.colOutlineVariant
            clip: true

            TrackCase {
                id: trackCase
                anchors.fill: parent
                visible: shell.variantIndex === 0
            }

            IncomingCase {
                id: incomingCase
                anchors.fill: parent
                visible: shell.variantIndex === 1
            }

            SequentialCase {
                id: sequentialCase
                anchors.fill: parent
                visible: shell.variantIndex === 2
            }
        }

        Rectangle {
            id: statePanel
            anchors.top: stage.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: stage.width
            height: 44
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2

            Text {
                anchors.fill: parent
                anchors.margins: 12
                text: shell.activeCase.stateSummary
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer2
            }
        }

        Rectangle {
            id: switcher
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            anchors.horizontalCenter: parent.horizontalCenter
            width: switcherRow.implicitWidth + 24
            height: 42
            radius: height / 2
            color: Appearance.colors.colPrimaryContainer

            Row {
                id: switcherRow
                anchors.centerIn: parent
                spacing: 12

                MaterialSymbol {
                    text: "arrow_back"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimaryContainer

                    TapHandler {
                        onTapped: shell.chooseVariant((shell.variantIndex + shell.variants.length - 1) % shell.variants.length)
                    }
                }

                Text {
                    text: shell.variants[shell.variantIndex].name
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnPrimaryContainer
                }

                MaterialSymbol {
                    text: "arrow_forward"
                    iconSize: 20
                    color: Appearance.colors.colOnPrimaryContainer

                    TapHandler {
                        onTapped: shell.chooseVariant((shell.variantIndex + 1) % shell.variants.length)
                    }
                }
            }
        }

        Shortcut {
            sequence: "Left"
            onActivated: shell.chooseVariant((shell.variantIndex + shell.variants.length - 1) % shell.variants.length)
        }

        Shortcut {
            sequence: "Right"
            onActivated: shell.chooseVariant((shell.variantIndex + 1) % shell.variants.length)
        }
    }

    component PillButton: Rectangle {
        id: pill

        required property string label
        property bool selected: false

        signal clicked

        width: pillLabel.implicitWidth + 24
        height: 32
        radius: height / 2
        color: selected ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer2
        border.width: 1
        border.color: selected ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

        Text {
            id: pillLabel
            anchors.centerIn: parent
            text: pill.label
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.Medium
            color: pill.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer2
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: pill.clicked()
        }
    }

    component DemoCard: Rectangle {
        id: card

        required property int selectedIndex
        default property alias paneContent: viewport.data
        readonly property alias viewportItem: viewport

        x: (parent.width - width) / 2
        y: 10
        width: shell.cardWidth(selectedIndex)
        height: shell.cardHeight(selectedIndex)
        radius: Appearance.rounding.large
        color: Appearance.colors.colLayer0
        border.width: 1
        border.color: Appearance.colors.colOutlineVariant

        Behavior on width {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration * shell.motionScale
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration * shell.motionScale
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        PrototypeTabBar {
            anchors.top: parent.top
            anchors.topMargin: 12
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            currentIndex: card.selectedIndex
        }

        Item {
            id: viewport
            anchors.top: parent.top
            anchors.topMargin: 12 + 64 + 8
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            clip: true
        }
    }

    component PrototypeTabBar: Item {
        id: bar

        required property int currentIndex

        height: 64

        Row {
            id: tabRow
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 60

            Repeater {
                model: shell.panes

                delegate: Item {
                    id: tab

                    required property int index
                    required property var modelData
                    readonly property bool active: bar.currentIndex === index

                    width: tabRow.width / shell.panes.length
                    height: tabRow.height

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.max(72, tabContent.implicitWidth + 24)
                        height: 52
                        radius: Appearance.rounding.small
                        color: tab.active ? Appearance.colors.colPrimaryContainer : hover.hovered ? Appearance.colors.colLayer1Hover : "transparent"

                        Column {
                            id: tabContent
                            anchors.centerIn: parent
                            spacing: 0

                            MaterialSymbol {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tab.modelData.icon
                                iconSize: 24
                                fill: tab.active ? 1 : 0
                                color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tab.modelData.name
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: shell.choosePane(tab.index)
                    }
                }
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Appearance.colors.colOutlineVariant
        }

        Rectangle {
            anchors.bottom: parent.bottom
            x: currentIndex * width
            width: parent.width / shell.panes.length
            height: 3
            radius: height / 2
            color: Appearance.colors.colPrimary

            Behavior on x {
                NumberAnimation {
                    duration: Appearance.animation.elementMove.duration * shell.motionScale
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    component DestinationPane: Rectangle {
        id: pane

        required property int paneIndex
        readonly property var paneData: shell.panes[paneIndex]

        width: paneData.width
        height: paneData.height
        radius: Appearance.rounding.normal
        color: [Appearance.colors.colSecondaryContainer, Appearance.colors.colTertiaryContainer, Appearance.colors.colPrimaryContainer][paneIndex]

        MaterialSymbol {
            id: heroIcon
            anchors.top: parent.top
            anchors.topMargin: 28
            anchors.horizontalCenter: parent.horizontalCenter
            text: pane.paneData.icon
            iconSize: 48
            fill: 1
            color: [Appearance.colors.colSecondary, Appearance.colors.colTertiary, Appearance.colors.colPrimary][pane.paneIndex]
        }

        Text {
            id: paneTitle
            anchors.top: heroIcon.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            text: pane.paneData.name
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
            color: Appearance.colors.colOnSurface
        }

        Text {
            anchors.top: paneTitle.bottom
            anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${pane.paneData.width} × ${pane.paneData.height} pane · ${pane.paneData.detail}`
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnSurfaceVariant
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 28
            spacing: 12

            Repeater {
                model: pane.paneIndex === 2 ? 4 : pane.paneIndex === 1 ? 4 : 3

                delegate: Rectangle {
                    required property int index

                    width: (parent.width - (parent.children.length - 1) * parent.spacing) / parent.children.length
                    height: 118 + (index % 2) * 18
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer0
                    opacity: 0.82

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 12
                        height: 22 + index * 9
                        radius: Appearance.rounding.full
                        color: [Appearance.colors.colSecondary, Appearance.colors.colTertiary, Appearance.colors.colPrimary][pane.paneIndex]
                        opacity: 0.55
                    }
                }
            }
        }
    }

    component TrackCase: Item {
        id: caseRoot

        property int currentIndex: 0
        property int previousIndex: 0
        property string phase: "settled"
        readonly property string stateSummary: `variant=A  phase=${phase}  selected=${shell.panes[currentIndex].name}  slots=3  live content=${phase === "settled" ? "1" : "2"}  fade=none`

        function select(index: int): void {
            previousIndex = currentIndex;
            currentIndex = index;
        }

        function reset(index: int): void {
            trackMotion.enabled = false;
            currentIndex = index;
            previousIndex = index;
            phase = "settled";
            Qt.callLater(() => trackMotion.enabled = true);
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 526
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ACCEPTED — permanent geometry track, selected by tabs only; one live pane at rest and both live while the viewport crosses between them."
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }

        DemoCard {
            id: card
            selectedIndex: caseRoot.currentIndex

            Item {
                id: track
                x: -shell.trackX(caseRoot.currentIndex)
                width: shell.panes.reduce((sum, pane) => sum + pane.width, 0)
                height: parent.height

                Behavior on x {
                    id: trackMotion

                    NumberAnimation {
                        duration: Appearance.animation.elementMove.duration * shell.motionScale
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                        onRunningChanged: caseRoot.phase = running ? `sliding ${shell.panes[caseRoot.previousIndex].name} → ${shell.panes[caseRoot.currentIndex].name}` : "settled"
                    }
                }

                Repeater {
                    model: shell.panes

                    delegate: DestinationPane {
                        required property int index
                        required property var modelData

                        paneIndex: index
                        x: shell.trackX(index)
                    }
                }
            }
        }
    }

    component IncomingCase: Item {
        id: caseRoot

        property int currentIndex: 0
        property string phase: "settled"
        readonly property string stateSummary: `variant=B  phase=${phase}  selected=${shell.panes[currentIndex].name}  Loader content=1  outgoing=destroyed immediately  fade=removed`

        function select(index: int): void {
            const direction = index > currentIndex ? 1 : -1;
            slide.stop();
            currentIndex = index;
            pane.paneIndex = index;
            pane.x = direction * card.viewportItem.width;
            slide.from = pane.x;
            slide.to = 0;
            slide.start();
        }

        function reset(index: int): void {
            slide.stop();
            currentIndex = index;
            pane.paneIndex = index;
            pane.x = 0;
            phase = "settled";
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 526
            anchors.horizontalCenter: parent.horizontalCenter
            text: "The existing cut-then-fade becomes cut-then-slide: ownership stays simple, but there is no outgoing pane to hand motion to."
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }

        DemoCard {
            id: card
            selectedIndex: caseRoot.currentIndex

            DestinationPane {
                id: pane
                paneIndex: 0
            }

            NumberAnimation {
                id: slide
                target: pane
                property: "x"
                duration: Appearance.animation.elementMove.duration * shell.motionScale
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                onStarted: caseRoot.phase = `incoming ${shell.panes[caseRoot.currentIndex].name}`
                onFinished: caseRoot.phase = "settled"
            }
        }
    }

    component SequentialCase: Item {
        id: caseRoot

        property int currentIndex: 0
        property int targetIndex: 0
        property int direction: 1
        property string phase: "settled"
        readonly property string stateSummary: `variant=C  phase=${phase}  selected=${shell.panes[currentIndex].name}  Loader content=1  source swap=${phase === "incoming" ? "done" : "pending"}  fade=removed`

        function select(index: int): void {
            journey.stop();
            pane.x = 0;
            direction = index > pane.paneIndex ? 1 : -1;
            targetIndex = index;
            currentIndex = index;
            exitMotion.from = 0;
            exitMotion.to = -direction * card.viewportItem.width;
            journey.start();
        }

        function reset(index: int): void {
            journey.stop();
            currentIndex = index;
            targetIndex = index;
            pane.paneIndex = index;
            pane.x = 0;
            phase = "settled";
        }

        Text {
            anchors.top: parent.top
            anchors.topMargin: 526
            anchors.horizontalCenter: parent.horizontalCenter
            text: "A single Loader can show both directions only in sequence; the card reaches its target while the content still owes a second move."
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
        }

        DemoCard {
            id: card
            selectedIndex: caseRoot.currentIndex

            DestinationPane {
                id: pane
                paneIndex: 0
            }

            SequentialAnimation {
                id: journey

                NumberAnimation {
                    id: exitMotion
                    target: pane
                    property: "x"
                    duration: Appearance.animation.elementMove.duration * shell.motionScale
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }

                ScriptAction {
                    script: {
                        pane.paneIndex = caseRoot.targetIndex;
                        pane.x = caseRoot.direction * card.viewportItem.width;
                        caseRoot.phase = "incoming";
                    }
                }

                NumberAnimation {
                    target: pane
                    property: "x"
                    to: 0
                    duration: Appearance.animation.elementMove.duration * shell.motionScale
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                }

                onStarted: caseRoot.phase = "outgoing"
                onFinished: caseRoot.phase = "settled"
            }
        }
    }
}
