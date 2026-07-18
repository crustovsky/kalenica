import QtQuick
import Quickshell

BarItem {
    id: root
    clickable: false

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    onScrolled: delta => cal.flip(delta)

    CalendarPopup {
        id: cal
        anchorItem: root
        anchorHovered: root.hovered
    }

    BarText {
        color: root.fg
        text: Qt.formatDateTime(clock.date, Config.modules.clock.format)
    }
}
