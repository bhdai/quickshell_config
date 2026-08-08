//@ pragma UseQApplication

import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

/**
 * PROTOTYPE — throwaway. Answers issue #137: what a dashboard tab looks like once it carries
 * an icon over its label, and what that costs `TABBAR_H`.
 *
 * Run it:  qs -p prototypes/icon-tabs
 *
 * Every variant is drawn at once at the calendar destination's real card width (896 - 2*PAD),
 * so they are compared against each other rather than against a memory. Each reports the
 * height it actually needs, measured from live font metrics, in the caption beside it — that
 * number is the answer the ticket is asking for.
 */
ShellRoot {
    id: shell

    // The calendar destination's pane width. The widest card the tab row ever spans; the
    // wallpaper tab is narrower, which is why no variant may depend on a fixed tab width.
    readonly property real barWidth: 872

    readonly property var iconSetA: [
        {
            label: "Dashboard",
            icon: "dashboard"
        },
        {
            label: "Wallpaper",
            icon: "wallpaper"
        },
        {
            label: "Performance",
            icon: "speed"
        }
    ]

    readonly property var iconSetB: [
        {
            label: "Calendar",
            icon: "event"
        },
        {
            label: "Wallpaper",
            icon: "image"
        },
        {
            label: "Performance",
            icon: "monitoring"
        }
    ]

    property int currentIndex: 0
    property var icons: shell.iconSetA
    // The second line's size is its own decision, not a detail: `small` (15) is what the
    // label-only tab uses today, `smaller` (12) is what stops a two-line tab dominating the
    // chrome. Toggling it re-measures everything.
    property real labelSize: Appearance.font.pixelSize.small

    FloatingWindow {
        id: window

        implicitWidth: shell.barWidth + 260
        implicitHeight: 620
        color: Appearance.colors.colLayer0
        visible: true

        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 18

            Row {
                spacing: 12

                Text {
                    text: "#137 — icon-over-label tabs. Click a tab; every variant follows."
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer0
                    anchors.verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    width: iconSetLabel.implicitWidth + 20
                    height: iconSetLabel.implicitHeight + 10
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: iconSetLabel
                        anchors.centerIn: parent
                        text: shell.icons === shell.iconSetA ? "icon set A — click to swap" : "icon set B — click to swap"
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.icons = shell.icons === shell.iconSetA ? shell.iconSetB : shell.iconSetA
                    }
                }

                Rectangle {
                    width: labelSizeLabel.implicitWidth + 20
                    height: labelSizeLabel.implicitHeight + 10
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: labelSizeLabel
                        anchors.centerIn: parent
                        text: `label ${shell.labelSize}px — click to swap`
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: shell.labelSize = shell.labelSize === Appearance.font.pixelSize.smaller ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.smaller
                    }
                }
            }

            Case {
                caption: "A — today: label only, RippleButton over the whole cell"
                note: "TABBAR_H = 48"
                bar: LabelOnly {
                    width: shell.barWidth
                }
            }

            Case {
                caption: "B — icon over label, fill 0→1, state layer still the whole cell"
                note: "the smallest change from A"
                bar: IconOverLabel {
                    width: shell.barWidth
                    pill: false
                    animateFill: true
                }
            }

            Case {
                caption: "C — icon over label, caelestia's content-hugging pill state layer"
                note: "faithful to the reference"
                bar: IconOverLabel {
                    width: shell.barWidth
                    pill: true
                    animateFill: true
                }
            }

            Case {
                caption: "D — icon beside label on one line"
                note: "M3's other primary tab; stays at 48"
                bar: IconBesideLabel {
                    width: shell.barWidth
                }
            }

            Case {
                caption: "E — icon only, no label"
                note: "cheapest; loses the words"
                bar: IconOnly {
                    width: shell.barWidth
                }
            }
        }

        // Laid out but never drawn: the height of a two-line tab is font metrics, so the
        // combinations not on screen are measured here rather than estimated.
        Item {
            visible: false

            IconOverLabel {
                width: shell.barWidth
                probeName: "probe-icon24-label12"
                glyphSize: 24
                labelSize: 12
            }
            IconOverLabel {
                width: shell.barWidth
                probeName: "probe-icon24-label15"
                glyphSize: 24
                labelSize: 15
            }
            IconOverLabel {
                width: shell.barWidth
                probeName: "probe-icon20-label12"
                glyphSize: 20
                labelSize: 12
            }
            IconOverLabel {
                width: shell.barWidth
                probeName: "probe-icon20-label15"
                glyphSize: 20
                labelSize: 15
            }
        }

        // Everything the ticket has to name, measured rather than guessed, so the numbers
        // survive a font change on another machine.
        Timer {
            interval: 600
            running: true
            repeat: false
            onTriggered: {
                const report = [];
                const walk = item => {
                    if (item.variantName !== undefined)
                        report.push(`${item.variantName} barHeight=${Math.round(item.height)} content=${Math.round(item.contentHeight)} indicator=${Math.round(item.indicatorWidth)}`);
                    for (const child of item.children)
                        walk(child);
                };
                walk(window.contentItem);
                for (const line of report)
                    console.log("MEASURED " + line);

                // What a new TABBAR_H does to the two destinations and the window they share.
                // MARGIN 10, PAD 12, GAP 8; panes are 428 (calendar) and 424 (wallpaper).
                for (const h of [48, 60, 64, 68, 72]) {
                    const cardH = pane => pane + 24 + h + 8;
                    console.log(`CHROME tabbar=${h} calendarCard=${cardH(428)} wallpaperCard=${cardH(424)} windowH=${Math.max(cardH(428), cardH(424)) + 20}`);
                }
            }
        }
    }

    component Case: Row {
        id: box

        property string caption
        property string note
        property Item bar

        spacing: 14

        children: [bar, captionColumn]

        Column {
            id: captionColumn
            width: 240
            spacing: 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: box.caption
                width: parent.width
                wrapMode: Text.WordWrap
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer0
            }

            Text {
                text: `${box.note}  •  needs ${Math.round(box.bar.height)}px`
                width: parent.width
                wrapMode: Text.WordWrap
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
    }

    // --- A: what DashTabBar draws today, transplanted so the comparison is fair ---

    component LabelOnly: Item {
        id: labelOnly

        readonly property string variantName: "A-label-only"
        readonly property real contentHeight: 48 - 3
        readonly property real indicatorWidth: indicator.width

        height: 48

        Row {
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: labelOnly.height - 3

            Repeater {
                model: shell.icons

                delegate: RippleButton {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool active: shell.currentIndex === index
                    readonly property real labelX: x + (width - label.implicitWidth) / 2
                    readonly property real labelWidth: label.implicitWidth

                    width: row.width / 3
                    height: row.height
                    buttonRadius: Appearance.rounding.small
                    colBackground: "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: shell.currentIndex = index

                    contentItem: Text {
                        id: label
                        text: tab.modelData.label
                        font.family: Appearance.font.family.main
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                            }
                        }
                    }
                }
            }
        }

        Divider {}

        Indicator {
            id: indicator
            row: row
        }
    }

    // --- B and C: the two-line tab. `pill` is the only difference between them ---

    component IconOverLabel: Item {
        id: stacked

        property bool pill: false
        property bool animateFill: true
        property real labelSize: shell.labelSize
        property real glyphSize: 24
        property string probeName: ""

        readonly property string variantName: probeName !== "" ? probeName : (pill ? "C-icon-over-label-pill" : "B-icon-over-label-cell") + `-label${labelSize}-icon${glyphSize}`
        // The natural height of the tallest tab's content — the number TABBAR_H is built from.
        property real contentHeight: 0
        readonly property real indicatorWidth: indicator.width

        // The lane the icon and label need, plus breathing room above and below, plus the 3px
        // indicator lane. 6 rather than caelestia's 5 is what rounds the 49px of icon-and-label
        // this font gives to M3's 64.
        readonly property real spacing: 6
        height: contentHeight + 2 * spacing + 3

        Row {
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: stacked.height - 3

            Repeater {
                model: shell.icons

                delegate: Item {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool active: shell.currentIndex === index
                    // What the indicator hugs: the wider of the two lines, not the cell.
                    readonly property real labelWidth: Math.max(icon.implicitWidth, label.implicitWidth)
                    readonly property real labelX: x + (width - labelWidth) / 2

                    width: row.width / 3
                    height: row.height

                    onHeightChanged: stacked.contentHeight = Math.max(stacked.contentHeight, icon.implicitHeight + label.implicitHeight)
                    Component.onCompleted: stacked.contentHeight = Math.max(stacked.contentHeight, icon.implicitHeight + label.implicitHeight)

                    Rectangle {
                        // C hugs the two lines; B fills the cell, which is what RippleButton
                        // does today.
                        anchors.centerIn: parent
                        width: stacked.pill ? tab.labelWidth + 24 : parent.width
                        height: stacked.pill ? stacked.contentHeight + 2 * stacked.spacing : parent.height
                        radius: Appearance.rounding.small
                        color: hover.hovered ? Appearance.colors.colLayer1Hover : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

                    MaterialSymbol {
                        id: icon
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: label.top
                        text: tab.modelData.icon
                        iconSize: stacked.glyphSize
                        fill: tab.active ? 1 : 0
                        color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant

                        Behavior on fill {
                            enabled: stacked.animateFill
                            NumberAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Appearance.animation.expressiveEffects
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                            }
                        }
                    }

                    Text {
                        id: label
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: stacked.spacing
                        text: tab.modelData.label
                        font.family: Appearance.font.family.main
                        font.pixelSize: stacked.labelSize
                        font.weight: Font.Medium
                        color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.elementMove.duration
                                easing.type: Appearance.animation.elementMove.type
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: shell.currentIndex = tab.index
                    }
                }
            }
        }

        Divider {}

        Indicator {
            id: indicator
            row: row
        }
    }

    // --- D: one line, icon leading the label ---

    component IconBesideLabel: Item {
        id: beside

        readonly property string variantName: "D-icon-beside-label"
        readonly property real contentHeight: 48 - 3
        readonly property real indicatorWidth: indicator.width

        height: 48

        Row {
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: beside.height - 3

            Repeater {
                model: shell.icons

                delegate: Item {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool active: shell.currentIndex === index
                    readonly property real labelWidth: pair.implicitWidth
                    readonly property real labelX: x + (width - pair.implicitWidth) / 2

                    width: row.width / 3
                    height: row.height

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: hover.hovered ? Appearance.colors.colLayer1Hover : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

                    Row {
                        id: pair
                        anchors.centerIn: parent
                        spacing: 6

                        MaterialSymbol {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.icon
                            iconSize: 20
                            fill: tab.active ? 1 : 0
                            color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                            Behavior on fill {
                                NumberAnimation {
                                    duration: Appearance.animation.elementMove.duration
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.elementMove.duration
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.label
                            font.family: Appearance.font.family.main
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.Medium
                            color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.animation.elementMove.duration
                                }
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: shell.currentIndex = tab.index
                    }
                }
            }
        }

        Divider {}

        Indicator {
            id: indicator
            row: row
        }
    }

    // --- E: icons alone ---

    component IconOnly: Item {
        id: bare

        readonly property string variantName: "E-icon-only"
        readonly property real contentHeight: 48 - 3
        readonly property real indicatorWidth: indicator.width

        height: 48

        Row {
            id: row
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: bare.height - 3

            Repeater {
                model: shell.icons

                delegate: Item {
                    id: tab
                    required property int index
                    required property var modelData
                    readonly property bool active: shell.currentIndex === index
                    readonly property real labelWidth: icon.implicitWidth
                    readonly property real labelX: x + (width - icon.implicitWidth) / 2

                    width: row.width / 3
                    height: row.height

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: hover.hovered ? Appearance.colors.colLayer1Hover : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: 200
                            }
                        }
                    }

                    MaterialSymbol {
                        id: icon
                        anchors.centerIn: parent
                        text: tab.modelData.icon
                        iconSize: 24
                        fill: tab.active ? 1 : 0
                        color: tab.active ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                        Behavior on fill {
                            NumberAnimation {
                                duration: Appearance.animation.elementMove.duration
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.animation.elementMove.duration
                            }
                        }
                    }

                    HoverHandler {
                        id: hover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: shell.currentIndex = tab.index
                    }
                }
            }
        }

        Divider {}

        Indicator {
            id: indicator
            row: row
        }
    }

    // --- shared bits ---

    component Divider: Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Appearance.colors.colOutlineVariant
    }

    component Indicator: Rectangle {
        id: indicator

        required property Item row

        anchors.bottom: parent.bottom
        height: 3
        radius: height / 2
        color: Appearance.colors.colPrimary

        readonly property Item activeTab: {
            for (const child of indicator.row.children) {
                if (child.active)
                    return child;
            }
            return null;
        }

        readonly property real targetWidth: activeTab ? Math.max(24, activeTab.labelWidth) : 0
        readonly property real targetX: activeTab ? activeTab.labelX + (activeTab.labelWidth - targetWidth) / 2 : 0

        width: targetWidth
        x: targetX

        Behavior on x {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Appearance.animation.elementMove.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.expressiveFastSpatial
            }
        }
    }
}
