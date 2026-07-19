pragma Singleton
import QtQuick
import Quickshell

// appId -> themed icon path. The dash->dot retry recovers reverse-DNS PWAs
// (app_id "com-fastmail-fastmail" vs StartupWMClass "com.fastmail.Fastmail");
// it fails closed to the generic icon, so it never mis-resolves.
// Callers must also touch DesktopEntries.applications.values for the async scan.
Singleton {
    function forAppId(appId) {
        // empty app_id (e.g. Chromium PiP windows): heuristicLookup("") returns
        // an arbitrary StartupWMClass-less entry (upstream, 0.3.0 + master)
        if (appId === "")
            return Quickshell.iconPath("application-x-executable");
        const entry = DesktopEntries.heuristicLookup(appId)
                   ?? DesktopEntries.heuristicLookup(appId.replace(/-/g, "."));
        if (entry !== null && entry.icon !== "")
            return Quickshell.iconPath(entry.icon, "application-x-executable");
        return Quickshell.iconPath(appId, "application-x-executable");
    }
}
