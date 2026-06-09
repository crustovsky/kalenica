import QtQuick
import Quickshell.Services.UPower

BarItem {
    id: root

    tooltip: "Power profile: " + PowerProfile.toString(PowerProfiles.profile)
    onClicked: {
        if (PowerProfiles.profile === PowerProfile.PowerSaver)
            PowerProfiles.profile = PowerProfile.Balanced;
        else if (PowerProfiles.profile === PowerProfile.Balanced && PowerProfiles.hasPerformanceProfile)
            PowerProfiles.profile = PowerProfile.Performance;
        else
            PowerProfiles.profile = PowerProfile.PowerSaver;
    }

    BarText {
        color: root.fg
        text: PowerProfiles.profile === PowerProfile.Performance ? ""
            : PowerProfiles.profile === PowerProfile.PowerSaver ? ""
            : " "
    }
}
