import QtQuick
import Quickshell

BarItem {
    id: root

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Month calendar on hover is planned as a popup later; plain date for now.
    tooltip: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")

    BarText {
        color: root.fg
        text: Qt.formatDateTime(clock.date, "dd MMM HH:mm:ss")
    }
}
