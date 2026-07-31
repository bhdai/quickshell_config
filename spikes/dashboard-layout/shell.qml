//@ pragma UseQApplication
import QtQuick
import Quickshell
import qs.modules.common
import "mock.js" as Mock

// Dashboard layout spike for issue #95. See README.md.
//
// A FloatingWindow, not the PanelWindow the real popup will be: a spike that raised a
// layer surface could not be captured head-less, and the question is what the card looks
// like, which a normal window answers identically.
ShellRoot {
    id: shellRoot

    // Set by capture.sh. When present the spike renders every variant to a PNG and exits
    // instead of waiting for a person, which is what lets it be reviewed with no display.
    readonly property string captureDir: Quickshell.env("DASH_CAPTURE_DIR") ?? ""
    readonly property bool capturing: captureDir !== ""

    FloatingWindow {
        id: win

        implicitWidth: Mock.CARD_W + 40
        implicitHeight: Mock.CARD_H + (shellRoot.capturing ? 40 : 96)
        color: shellRoot.capturing ? "transparent" : "#0a0a0c"
        title: "spike: dashboard layout"

        Dashboard {
            id: card
            x: 20
            y: 20
            currentTab: "calendar"
            grid: Mock.GRIDS[gridIndex]
            headerVariant: Mock.HEADERS[headerIndex].key
            monthShift: monthShiftValue

            property int gridIndex: 0
            property int headerIndex: 0
            property int monthShiftValue: 0
        }

        // Deliberately outside the card and deliberately ugly, so nothing on the switcher
        // is mistaken for part of the design under review.
        Rectangle {
            visible: !shellRoot.capturing
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            width: switcherText.implicitWidth + 28
            height: 40
            radius: 20
            color: "#f2f2f5"

            Text {
                id: switcherText
                anchors.centerIn: parent
                color: "#101014"
                font.family: Appearance.font.family.monospace
                font.pixelSize: 12
                text: "◀ ▶ grid " + Mock.GRIDS[card.gridIndex].key + " · " + Mock.GRIDS[card.gridIndex].name + "    ▲ ▼ header " + Mock.HEADERS[card.headerIndex].key + " · " + Mock.HEADERS[card.headerIndex].name + "    m month " + card.monthShiftValue
            }
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Right)
                    card.gridIndex = (card.gridIndex + 1) % Mock.GRIDS.length;
                else if (event.key === Qt.Key_Left)
                    card.gridIndex = (card.gridIndex + Mock.GRIDS.length - 1) % Mock.GRIDS.length;
                else if (event.key === Qt.Key_Down)
                    card.headerIndex = (card.headerIndex + 1) % Mock.HEADERS.length;
                else if (event.key === Qt.Key_Up)
                    card.headerIndex = (card.headerIndex + Mock.HEADERS.length - 1) % Mock.HEADERS.length;
                else if (event.key === Qt.Key_M)
                    card.monthShiftValue = card.monthShiftValue === 0 ? 1 : 0;
                else if (event.key === Qt.Key_Tab)
                    card.currentTab = card.currentTab === "calendar" ? "wallpaper" : "calendar";
            }
        }

        // Every shot the review needs, in one run. August 2026 is the six-week month the
        // ticket asks for — it starts on a Saturday, so 5 + 31 spills past 35 cells.
        readonly property var shots: [
            { file: "calendar-header-1-bare-band", tab: "calendar", grid: 0, header: 0, month: 0 },
            { file: "calendar-header-2-card-band", tab: "calendar", grid: 0, header: 1, month: 0 },
            { file: "calendar-header-3-weather-forward", tab: "calendar", grid: 0, header: 2, month: 0 },
            { file: "calendar-six-week-month", tab: "calendar", grid: 0, header: 0, month: 1 },
            { file: "wallpaper-grid-A-4wide", tab: "wallpaper", grid: 0, header: 0, month: 0 },
            { file: "wallpaper-grid-B-3wide", tab: "wallpaper", grid: 1, header: 0, month: 0 },
            { file: "wallpaper-grid-C-4wide-paged", tab: "wallpaper", grid: 2, header: 0, month: 0 }
        ]

        // The next shot is applied from inside the grab's own callback, never alongside it.
        // grabToImage renders on a later frame, so advancing the variant in the same
        // handler that requested the grab captures the *next* variant under this one's
        // filename — which is exactly what the first run of this spike did.
        function shoot(i) {
            if (i >= shots.length) {
                Qt.quit();
                return;
            }
            const shot = shots[i];
            card.currentTab = shot.tab;
            card.gridIndex = shot.grid;
            card.headerIndex = shot.header;
            card.monthShiftValue = shot.month;
            settle.pending = i;
            settle.restart();
        }

        Timer {
            id: settle
            property int pending: 0
            // Long enough for the wallpaper tab's asynchronous JPEG decodes to land; a
            // shorter wait captures empty cells and proves nothing about whether a
            // photograph is legible at cell size.
            interval: 1200
            running: false
            onTriggered: {
                const shot = win.shots[settle.pending];
                const path = shellRoot.captureDir + "/" + shot.file + ".png";
                card.grabToImage(function (result) {
                    console.log("SHOT " + (result.saveToFile(path) ? "ok" : "FAILED") + " " + path);
                    win.shoot(settle.pending + 1);
                }, Qt.size(Mock.CARD_W * 2, Mock.CARD_H * 2));
            }
        }

        Timer {
            interval: 400
            running: shellRoot.capturing
            onTriggered: win.shoot(0)
        }

        Component.onCompleted: {
            console.log("METRICS card=" + Mock.CARD_W + "x" + Mock.CARD_H + " pane=" + Mock.PANE_W + "x" + Mock.PANE_H + " body=" + Mock.BODY_H + " column=" + Mock.COL_W);
            console.log("METRICS calendarNatural=" + Math.round(card.calendarNatural) + " bodyBudget=" + Mock.BODY_H);
            for (const g of Mock.GRIDS) {
                const m = Mock.gridMetrics(g);
                console.log("METRICS grid=" + g.key + " columns=" + g.columns + " rows=" + m.rows + " capacity=" + m.capacity + " cell=" + m.cellW + "x" + m.cellH + " footer=" + g.footer + " slack=" + m.slack);
            }
        }
    }
}
