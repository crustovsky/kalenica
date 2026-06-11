pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Centered password prompt for secured unknown wifi networks (replaces the
// vicinae wifi-commander fallback). Same modal mechanics as ConfirmDialog:
// unanchored overlay PanelWindow, exclusive keyboard focus while visible —
// keyboard input can't go into the anchored network popup itself (layer
// popups never get keyboard focus). Enter connects via connectWithPsk, Esc
// cancels, the eye button toggles password visibility. Stays open through
// the attempt: closes itself on success, keeps the text for editing on a
// wrong password.
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

                    Rectangle {
                        id: eye
                        width: inputBox.height
                        height: inputBox.height
                        radius: 8
                        color: eyeHover.hovered ? Theme.bgHover : "transparent"
                        border.width: 1
                        border.color: Theme.notifBorder

                        BarText {
                            anchors.centerIn: parent
                            text: root.showPsk ? "󰈉" : "󰈈"
                            color: eyeHover.hovered ? Theme.fgHover : Theme.notifFg
                        }

                        HoverHandler { id: eyeHover }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showPsk = !root.showPsk
                        }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Repeater {
                        model: ["Connect", "Cancel"]

                        Rectangle {
                            id: button
                            required property string modelData
                            required property int index

                            width: buttonText.implicitWidth + 28
                            height: buttonText.implicitHeight + 10
                            radius: 8
                            color: buttonHover.hovered ? Theme.bgHover : "transparent"
                            border.width: 1
                            border.color: Theme.notifBorder

                            BarText {
                                id: buttonText
                                anchors.centerIn: parent
                                text: button.modelData
                                color: buttonHover.hovered ? Theme.fgHover : Theme.notifFg
                                font.bold: false
                            }

                            HoverHandler { id: buttonHover }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (button.index === 0)
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
}
