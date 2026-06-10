pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// Modal confirmation popup (replaces the old gum-in-kitty power-confirm.sh
// and vicinae confirmations): centered floating card on the same screen as
// the bar, frosted by the quickshell-blur layer rule. Yes is preselected;
// arrows/Tab move the selection, Enter activates it, Y/N act directly,
// Esc cancels. Takes exclusive keyboard focus while visible.
Item {
    id: root

    property string prompt
    property var command: []
    property int selected: 0 // index into the Yes/No row, 0 = Yes

    function ask(text, cmd) {
        prompt = text;
        command = cmd;
        selected = 0;
        panel.visible = true;
    }

    visible: false

    PanelWindow {
        id: panel

        function accept() {
            visible = false;
            Quickshell.execDetached(root.command);
        }

        function activate() {
            if (root.selected === 0)
                accept();
            else
                visible = false;
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

        Rectangle {
            id: card
            anchors.fill: parent
            implicitWidth: content.implicitWidth + 48
            implicitHeight: content.implicitHeight + 32
            radius: 10
            color: Theme.notifBg
            border.width: 2
            border.color: Theme.notifBorder

            focus: true
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Left:
                case Qt.Key_Right:
                case Qt.Key_Tab:
                    root.selected = root.selected === 0 ? 1 : 0;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    panel.activate();
                    break;
                case Qt.Key_Y:
                    panel.accept();
                    break;
                case Qt.Key_N:
                case Qt.Key_Escape:
                    panel.visible = false;
                    break;
                }
            }

            Column {
                id: content
                anchors.centerIn: parent
                spacing: 14

                BarText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.prompt
                    color: Theme.notifFg
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10

                    Repeater {
                        model: ["Yes", "No"]

                        Rectangle {
                            id: button
                            required property string modelData
                            required property int index

                            readonly property bool active: root.selected === index

                            width: buttonText.implicitWidth + 28
                            height: buttonText.implicitHeight + 10
                            radius: 8
                            color: active ? Theme.bgHover : "transparent"
                            border.width: 1
                            border.color: Theme.notifBorder

                            BarText {
                                id: buttonText
                                anchors.centerIn: parent
                                text: button.modelData
                                color: button.active ? Theme.fgHover : Theme.notifFg
                                font.bold: false
                            }

                            HoverHandler {
                                onHoveredChanged: {
                                    if (hovered)
                                        root.selected = button.index;
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.selected = button.index;
                                    panel.activate();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
