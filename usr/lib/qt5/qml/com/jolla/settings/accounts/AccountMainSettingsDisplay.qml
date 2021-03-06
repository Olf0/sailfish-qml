import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Accounts 1.0
import org.nemomobile.systemsettings 1.0

Item {
    id: root

    property Provider accountProvider
    property bool accountEnabled
    property bool accountEnabledReadOnly
    property bool accountIsProvisioned
    property alias accountUserName: usernameLabel.text
    property alias accountDisplayName: accountDisplayNameField.text

    AboutSettings {
        id: aboutSettings
    }

    property bool _changingAccountStatus

    width: parent.width
    height: accountIcon.height
            + statusCombo.height
            + statusCombo.anchors.topMargin
            + accountDisplayNameField.height
            + Theme.paddingLarge

    onAccountEnabledChanged: {
        if (!_changingAccountStatus) {
            statusCombo.currentIndex = accountEnabled ? 0 : 1
        }
    }

    Component.onCompleted: {
        statusCombo.currentIndex = accountEnabled ? 0 : 1
    }

    function _changeAccountStatus(enableAccount) {
        _changingAccountStatus = true
        accountEnabled = enableAccount
        _changingAccountStatus = false
    }

    Image {
        id: accountIcon
        x: Theme.horizontalPageMargin
        width: Theme.iconSizeLarge
        height: width
        source: root.accountProvider.iconName
    }

    Label {
        id: displayNameLabel
        anchors {
            left: accountIcon.right
            leftMargin: Theme.paddingLarge
            right: parent.right
            rightMargin: Theme.horizontalPageMargin
            verticalCenter: accountIcon.verticalCenter
            verticalCenterOffset: usernameLabel.text != ""
                                  ? (-usernameLabel.implicitHeight - Theme.paddingMedium)/2
                                  : 0
        }
        color: Theme.highlightColor
        font.pixelSize: Theme.fontSizeLarge
        truncationMode: TruncationMode.Fade
        text: root.accountProvider.displayName
    }


    Label {
        id: usernameLabel
        anchors {
            top: displayNameLabel.bottom
            topMargin: Theme.paddingSmall
            left: displayNameLabel.left
            right: displayNameLabel.right
        }
        truncationMode: TruncationMode.Fade
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.secondaryHighlightColor
    }

    ComboBox {
        id: statusCombo
        anchors {
            top: accountIcon.bottom
            topMargin: Theme.paddingLarge
        }
        enabled: !root.accountEnabledReadOnly
        description: {
            if (root.accountIsProvisioned && root.accountEnabledReadOnly) {
                if (accountEnabled) {
                    //: Indicates that the account is currently enabled by MDM
                    //: %1 is an operating system name without the OS suffix
                    //% "Enabled by %1 Device Manager"
                    return qsTrId("settings-accounts-la-account_enabled_by_mdm")
                        .arg(aboutSettings.baseOperatingSystemName)
                } else {
                    //: Indicates that the account is currently disabled by MDM
                    //: %1 is an operating system name without the OS suffix
                    //% "Disabled by %1 Device Manager"
                    return qsTrId("settings-accounts-la-account_disabled_by_mdm")
                        .arg(aboutSettings.baseOperatingSystemName)
                }
            } else {
                return ""
            }
        }

        //: Indicates whether the account is currently enabled
        //% "Account status"
        label: qsTrId("settings-accounts-me-account_status")

        menu: ContextMenu {
            MenuItem {
                //: Indicates the account is currently enabled and active
                //% "Active"
                text: qsTrId("settings-accounts-me-account_active")
                onClicked: root._changeAccountStatus(true)
            }
            MenuItem {
                //: Indicates the account is currently not enabled
                //% "Disabled"
                text: qsTrId("settings-accounts-me-account_disabled")
                onClicked: root._changeAccountStatus(false)
            }
        }
    }

    TextField {
        id: accountDisplayNameField
        anchors.top: statusCombo.bottom
        width: parent.width

        //: Short name or summary for a user account
        //% "Description"
        label: qsTrId("components_accounts-la-account_description")
        placeholderText: label

        EnterKey.iconSource: "image://theme/icon-m-enter-close"
        EnterKey.onClicked: root.focus = true
    }
}
