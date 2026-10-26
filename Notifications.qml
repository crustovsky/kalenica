pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import Quickshell.Widgets

// Notification popups, replacing dunst: stacked cards in the top-right of the
// focused monitor (approximates dunst's follow=mouse). Left-click dismisses,
// right-click dismisses all, middle-click runs the default action; hovering
// the stack holds every card. Styling (offsets, padding, frame, radius, 5s
// timeout) mirrors the old dunstrc. Do not disturb (`qs ipc call
// notifications dnd`) works like dunst's pause: cards queue unseen with
// their timers stopped and all appear when it ends.
// The shell's own notifications (screenshots) skip D-Bus: notify() queues a
// LocalNotification with the same interface the card reads off a Notification.
Scope {
    id: root

    required property var osd

    property var local: []
    property alias dnd: persist.dnd

    PersistentProperties {
        id: persist
        reloadableId: "notifications"
        property bool dnd: false
    }

    IpcHandler {
        target: "notifications"

        function dnd(): void {
            root.dnd = !root.dnd;
            root.osd.showText(root.dnd ? "󰂛" : "󰂚",
                              root.dnd ? "do not disturb" : "notifications on");
        }
    }

    // actions: [{ identifier, text, invoke() }]; the first one doubles as
    // the middle-click default. critical: orange frame, never auto-expires.
    function notify(summary: string, body: string, image: string, actions: var,
                    critical: bool): void {
        const n = localNotification.createObject(root, {
            summary: summary, body: body, image: image, actions: actions,
            urgency: critical ? NotificationUrgency.Critical : NotificationUrgency.Normal });
        local = [...local, n];
    }

    component LocalNotification: QtObject {
        id: ln
        property string summary
        property string body
        property string image: ""
        readonly property string appIcon: ""
        property int urgency: NotificationUrgency.Normal
        readonly property int expireTimeout: -1
        property var actions: []

        function dismiss(): void {
            root.local = root.local.filter(n => n !== ln);
            ln.destroy();
        }

        function expire(): void {
            dismiss();
        }
    }

    Component {
        id: localNotification
        LocalNotification {}
    }

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: n => n.tracked = true
    }

    // diffed, so a card arriving or leaving doesn't rebuild (and re-time)
    // the others
    ScriptModel {
        id: cards
        values: [...server.trackedNotifications.values, ...root.local]
    }

    PanelWindow {
        screen: Screens.focused()

        visible: cards.values.length > 0 && !root.dnd
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
        // Top, not Overlay: a fullscreen window (movie, game) covers the
        // stack instead of being interrupted by it; cards wait underneath
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "kalenica-notifications"
        color: "transparent"
        implicitWidth: 350
        implicitHeight: column.implicitHeight

        Column {
            id: column
            width: parent.width
            spacing: 8

            // a card must not vanish under the cursor on its way to a button
            HoverHandler { id: stackHover }

            Repeater {
                model: cards

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
                        // critical notifications stay until dismissed; the
                        // timer restarts in full once the mouse leaves
                        interval: card.modelData.expireTimeout > 0
                            ? card.modelData.expireTimeout
                            : Config.modules.notifications.timeout
                        running: card.modelData.urgency !== NotificationUrgency.Critical
                            && !stackHover.hovered && !root.dnd
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
                                for (const n of [...cards.values])
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

                                    DialogButton {
                                        id: actionButton
                                        required property var modelData

                                        padX: 16
                                        padY: 8
                                        text: actionButton.modelData.text !== ""
                                            ? actionButton.modelData.text
                                            : actionButton.modelData.identifier
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
