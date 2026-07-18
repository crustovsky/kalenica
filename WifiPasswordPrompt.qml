pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Centered password prompt for secured unknown wifi networks, modal like
// ConfirmDialog (a separate window because layer popups never get keyboard
// focus). Enter/Connect tries connectWithPsk and stays open: closes itself
// on success, keeps the text for editing on a wrong password.
Item {
    id: root

    property var network: null
    property bool showPsk: false
    property string status: ""

    function ask(net) {
        network = net;
        showPsk = false;
        status = "";
        input.text = "";
        panel.visible = true;
        input.forceActiveFocus();
    }

    visible: false

    Connections {
        target: root.network

        function onConnectionFailed() {
            root.status = "wrong password";
        }
        function onConnectedChanged() {
            if (root.network.connected)
                panel.visible = false;
        }
    }

    PanelWindow {
        id: panel

        function submit() {
            if (input.text === "" || root.network === null
                    || root.status === "connecting…")
                return;
            root.status = "connecting…";
            root.network.connectWithPsk(input.text);
        }

        screen: root.QsWindow.window?.screen ?? null
        visible: false
        // no anchors: the compositor centers an unanchored layer surface
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive
                                             : WlrKeyboardFocus.None
        color: "transparent"
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight

        // don't keep secrets around
        onVisibleChanged: {
            if (!visible)
                input.text = "";
        }

        Rectangle {
            id: card
            anchors.fill: parent
            implicitWidth: content.implicitWidth + 48
            implicitHeight: content.implicitHeight + 32
            radius: 10
            color: Theme.notifBg
            border.width: 2
            border.color: Theme.notifBorder

            Column {
                id: content
                anchors.centerIn: parent
                spacing: 14

                BarText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    // doubles as the status line: no extra row, no resize
                    text: root.status !== "" ? root.status
                        : `wifi password for "${root.network !== null ? root.network.name : ""}"`
                    color: root.status === "wrong password" ? Theme.critical : Theme.notifFg
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    Rectangle {
                        id: inputBox
                        width: 380
                        height: input.implicitHeight + 14
                        radius: 8
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.notifBorder

                        TextInput {
                            id: input
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            color: Theme.notifFg
                            echoMode: root.showPsk ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            focus: true
                            onTextEdited: root.status = ""
                            onAccepted: panel.submit()
                            Keys.onEscapePressed: panel.visible = false
                        }
                    }

                    DialogButton {
                        width: inputBox.height
                        height: inputBox.height
                        text: root.showPsk ? "󰈉" : "󰈈"
                        onClicked: root.showPsk = !root.showPsk
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Repeater {
                        model: ["Connect", "Cancel"]

                        DialogButton {
                            required property string modelData
                            required property int index

                            text: modelData
                            onClicked: {
                                if (index === 0)
                                    panel.submit();
                                else
                                    panel.visible = false;
                            }
                        }
                    }
                }

            }
        }
    }
}
