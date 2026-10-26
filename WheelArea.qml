import QtQuick

// Wheel-only mouse area that emits whole notches. A mouse sends 120 units
// per click, a touchpad a stream of fractions; accumulating here means every
// consumer steps once per notch instead of once per finger twitch.
// Positive = scrolled up/away.
MouseArea {
    id: root

    signal stepped(int steps)
    property real acc: 0

    acceptedButtons: Qt.NoButton
    onWheel: wheel => {
        acc += wheel.angleDelta.y;
        const steps = Math.trunc(acc / 120);
        if (steps !== 0) {
            acc -= steps * 120;
            root.stepped(steps);
        }
    }
}
