pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

// Month-overview calendar on clock hover: today highlighted, Monday-first
// rows with ISO week numbers, scroll flips months. Display only — no events.
// Show delay and hide grace bridge the mouse gap between bar and popup.
PopupWindow {
    id: root

    required property Item anchorItem
    required property bool anchorHovered

    property var today: new Date()
    property int offset: 0 // months away from the current one

    readonly property var monthStart: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var weeks: {
        const year = monthStart.getFullYear();
        const month = monthStart.getMonth();
        const lead = (monthStart.getDay() + 6) % 7; // Monday-first
        const dayCount = new Date(year, month + 1, 0).getDate();
        const rows = [];
        let day = 1 - lead;
        while (day <= dayCount) {
            // ISO week is defined by the row's Thursday (day + 3)
            const row = { num: isoWeek(new Date(year, month, day + 3)), days: [] };
            for (let i = 0; i < 7; i++, day++)
                row.days.push(day >= 1 && day <= dayCount ? day : 0);
            rows.push(row);
        }
        return rows;
    }
    readonly property int todayDay: offset === 0 ? today.getDate() : 0

    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        t.setUTCDate(t.getUTCDate() - (t.getUTCDay() + 6) % 7 + 3);
        const week1 = new Date(Date.UTC(t.getUTCFullYear(), 0, 4));
        return 1 + Math.round(((t - week1) / 86400000 - 3 + (week1.getUTCDay() + 6) % 7) / 7);
    }

    function flip(delta) {
        offset += delta > 0 ? -1 : 1; // scroll up = back in time
    }

    readonly property bool wanted: anchorHovered || popHover.hovered
    onWantedChanged: {
        if (wanted) {
            hideGrace.stop();
            if (!visible)
                showDelay.restart();
        } else {
            showDelay.stop();
            hideGrace.restart();
        }
    }

    Timer {
        id: showDelay
        interval: Config.timing.tooltipDelay
        onTriggered: {
            root.today = new Date();
            root.offset = 0;
            root.visible = true;
        }
    }

    Timer {
        id: hideGrace
        interval: 400
        onTriggered: root.visible = false
    }

    anchor.item: anchorItem
    anchor.rect.w: anchorItem.width
    anchor.rect.h: anchorItem.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    color: "transparent"
    implicitWidth: column.implicitWidth + 24
    implicitHeight: column.implicitHeight + 20

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.bg
        // springy scale-in on open (window unmaps instantly on close → opening only)
        transformOrigin: Item.Top
        scale: root.visible ? 1 : 0.85
        Behavior on scale {
            NumberAnimation { duration: Config.timing.popupGrow; easing.type: Easing.OutBack; easing.overshoot: 1.3 }
        }

        HoverHandler { id: popHover }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => root.flip(wheel.angleDelta.y)
        }

        Column {
            id: column
            anchors.centerIn: parent
            spacing: 2

            BarText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.monthStart, "MMMM yyyy")
                bottomPadding: 4
            }

            Row {
                Item { width: 30; height: 22 } // week-number column
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Item {
                        required property string modelData
                        width: 30
                        height: 22
                        BarText {
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: Theme.fgDim
                        }
                    }
                }
            }

            Repeater {
                model: root.weeks

                Row {
                    id: weekRow
                    required property var modelData

                    Item {
                        width: 30
                        height: 24
                        BarText {
                            anchors.centerIn: parent
                            text: weekRow.modelData.num
                            color: Theme.fgDim
                            font.bold: false
                        }
                    }

                    Repeater {
                        model: weekRow.modelData.days

                        Item {
                            id: cell
                            required property int modelData

                            readonly property bool isToday: modelData !== 0
                                && modelData === root.todayDay

                            width: 30
                            height: 24

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 22
                                radius: 6
                                visible: cell.isToday
                                color: Theme.bgHover
                            }

                            BarText {
                                anchors.centerIn: parent
                                visible: cell.modelData !== 0
                                text: cell.modelData
                                color: cell.isToday ? Theme.fgHover : Theme.fg
                                font.bold: cell.isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
