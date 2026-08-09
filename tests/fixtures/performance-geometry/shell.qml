import Quickshell
import QtQuick
import qs.modules.dashboard
import qs.services

ShellRoot {
    FloatingWindow {
        id: window

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
            currentTab: "performance"
        }

        function cardNamed(pane: Item, title: string): Item {
            return pane.children.find(child => child.title === title) ?? null;
        }

        function rectangle(item: Item, pane: Item): string {
            const origin = item.mapToItem(pane, 0, 0);
            return `${Math.round(origin.x)},${Math.round(origin.y)} ${Math.round(item.width)}x${Math.round(item.height)}`;
        }

        function visibleTexts(item: Item): var {
            const texts = [];
            const walk = child => {
                if (!child.visible)
                    return;
                if (child.text !== undefined && child.text !== "")
                    texts.push(child.text);
                for (const descendant of child.children)
                    walk(descendant);
            };
            walk(item);
            return texts;
        }

        function plotsIn(item: Item): var {
            const plots = [];
            const walk = child => {
                if (child.primaryRole !== undefined && child.collecting !== undefined
                        && child.primaryLines !== undefined)
                    plots.push(child);
                for (const descendant of child.children)
                    walk(descendant);
            };
            walk(item);
            return plots;
        }

        function fail(message: string): void {
            console.log(`PERFORMANCE FAIL ${message}`);
            Qt.quit();
        }

        Timer {
            interval: 100
            running: true
            onTriggered: {
                const pane = card.paneItem;
                const cpu = window.cardNamed(pane, "CPU");
                const memory = window.cardNamed(pane, "Memory");
                const network = window.cardNamed(pane, "Network");
                const storage = window.cardNamed(pane, "Storage");
                if (!pane || !cpu || !memory || !network || !storage) {
                    window.fail("the production Performance pane did not expose all four cards");
                    return;
                }

                const plots = window.plotsIn(pane);
                const readyPlots = plots.filter(plot => !plot.collecting && plot.primaryLines.length > 0);
                const cpuTexts = window.visibleTexts(cpu);
                const networkTexts = window.visibleTexts(network);
                const memoryTexts = window.visibleTexts(memory);
                const complete = ResourceUsage.profile === "complete";
                const expectedDownload = complete ? "1.5 MiB/s" : "—";
                const expectedUpload = complete ? "256.0 KiB/s" : "32.0 KiB/s";
                const download = networkTexts.includes(expectedDownload) ? expectedDownload : "missing";
                const upload = networkTexts.includes(expectedUpload) ? expectedUpload : "missing";
                const swapVisible = memoryTexts.includes("Swap");
                const swap = memory.swapConfigured === swapVisible ? memory.swapConfigured : "mismatch";
                const collectingMessage = "Collecting 60-second history…";
                const collectingCards = [cpu, memory, network].map(metric => window.visibleTexts(metric).filter(text => text === collectingMessage).length);
                const headlines = [cpuTexts.includes(complete ? "58" : "31"), memoryTexts.includes(complete ? "75" : "63"), storage.occupancyKnown];

                console.log(`PERFORMANCE ${ResourceUsage.profile} card=${card.width}x${card.height} pane=${pane.width}x${pane.height}`);
                console.log(`PERFORMANCE ${ResourceUsage.profile} cpu=${window.rectangle(cpu, pane)} memory=${window.rectangle(memory, pane)} network=${window.rectangle(network, pane)} storage=${window.rectangle(storage, pane)}`);
                const collectionState = complete ? "" : ` collecting-cards=${collectingCards.join(",")}`;
                console.log(`PERFORMANCE ${ResourceUsage.profile} history=${ResourceUsage.history.count} plots=${plots.length} collecting=${plots.length - readyPlots.length}${collectionState}` + ` cpu-temperature=${cpu.temperatureText} critical=${cpu.criticalText} swap=${swap}` + ` download=${download} upload=${upload} headlines=${headlines.join(",")}`);

                Qt.quit();
            }
        }
    }
}
