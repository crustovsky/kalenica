pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Widgets

// Notification popups, replacing dunst: stacked cards in the top-right of the
// focused monitor (approximates dunst's follow=mouse). Left-click dismisses,
// right-click dismisses all, middle-click runs the default action. Styling
// (offsets, padding, frame, radius, 5s timeout) mirrors the old dunstrc.
Scope {
    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: n => n.tracked = true
    }

    PanelWindow {
        screen: {
            const focused = Hyprland.focusedMonitor;
            for (const s of Quickshell.screens) {
                if (focused !== null && s.name === focused.name)
                    return s;
            }
            return Quickshell.screens[0] ?? null;
        }

        visible: server.trackedNotifications.values.length > 0
        anchors {
            top: true
            right: true
        }
        margins {
            top: 10
            right: 10
        }
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        implicitWidth: 350
        implicitHeight: column.implicitHeight

        Column {
            id: column
            width: parent.width
            spacing: 8

            Repeater {
                model: server.trackedNotifications

                Rectangle {
                    id: card
                    required property var modelData

                    // The "default" action belongs to a click on the card
                    // (middle-click, per dunst), not a button; kitty et al.
                    // send it with a blank label.
                    readonly property var buttonActions: modelData.actions.filter(
                        a => a.identifier !== "default" && a.text.trim() !== "")

                    width: column.width
                    implicitHeight: content.implicitHeight + 16
                    radius: 10
                    color: Theme.notifBg
                    border.width: 2
                    border.color: modelData.urgency === NotificationUrgency.Critical
                        ? Theme.notifBorderCritical : Theme.notifBorder

                    Timer {
                        // expireTimeout is in milliseconds, -1 = sender default;
                        // critical notifications stay until dismissed
                        interval: card.modelData.expireTimeout > 0
                            ? card.modelData.expireTimeout
                            : Config.modules.notifications.timeout
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                        onTriggered: card.modelData.expire()
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                card.modelData.dismiss();
                            } else if (mouse.button === Qt.RightButton) {
                                for (const n of [...server.trackedNotifications.values])
                                    n.dismiss();
                            } else {
                                const actions = card.modelData.actions;
                                const def = actions.find(a => a.identifier === "default")
                                    ?? actions[0];
                                if (def !== undefined) {
                                    def.invoke();
                                    card.modelData.dismiss();
                                }
                            }
                        }
                    }

                    Row {
                        id: content
                        x: 8
                        y: 8
                        width: parent.width - 16
                        spacing: 8

                        IconImage {
                            id: icon
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 40
                            visible: source.toString() !== ""
                            source: {
                                const n = card.modelData;
                                if (n.image !== "")
                                    return n.image;
                                if (n.appIcon !== "") {
                                    const p = Quickshell.iconPath(n.appIcon, true);
                                    return p !== "" ? p : n.appIcon;
                                }
                                return "";
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - (icon.visible ? icon.width + content.spacing : 0)
                            spacing: 2

                            BarText {
                                width: parent.width
                                text: card.modelData.summary
                                color: Theme.notifFg
                                wrapMode: Text.Wrap
                                textFormat: Text.PlainText
                            }

                            BarText {
                                width: parent.width
                                visible: text !== ""
                                text: card.modelData.body
                                color: Theme.notifFg
                                font.bold: false
                                wrapMode: Text.Wrap
                                textFormat: Text.StyledText
                                linkColor: Theme.notifBorder
                                onLinkActivated: link => Qt.openUrlExternally(link)
                            }

                            Row {
                                spacing: 6
                                visible: card.buttonActions.length > 0

                                Repeater {
                                    model: card.buttonActions

                                    Rectangle {
                                        id: actionButton
                                        required property var modelData

                                        width: actionText.implicitWidth + 16
                                        height: actionText.implicitHeight + 8
                                        radius: 8
                                        color: actionHover.hovered ? Theme.bgHover : "transparent"
                                        Behavior on color {
                                            ColorAnimation { duration: Config.timing.hoverFade }
                                        }
                                        border.width: 1
                                        border.color: Theme.notifBorder

                                        BarText {
                                            id: actionText
                                            anchors.centerIn: parent
                                            text: actionButton.modelData.text !== ""
                                                ? actionButton.modelData.text
                                                : actionButton.modelData.identifier
                                            color: actionHover.hovered ? Theme.fgHover : Theme.notifFg
                                            font.bold: false
                                        }

                                        HoverHandler { id: actionHover }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                actionButton.modelData.invoke();
                                                card.modelData.dismiss();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
