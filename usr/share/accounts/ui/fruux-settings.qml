import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Accounts 1.0
import com.jolla.settings.accounts 1.0

OnlineSyncAccountSettingsAgent {
    services: [
        accountManager.service("fruux-carddav"),
        accountManager.service("fruux-caldav")
    ]
}
