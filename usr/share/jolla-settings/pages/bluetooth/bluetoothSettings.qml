import QtQuick 2.0
import Sailfish.Silica 1.0
import MeeGo.Connman 0.2
import Sailfish.Bluetooth 1.0
import com.jolla.settings.bluetooth.translations 1.0
import org.kde.bluezqt 1.0 as BluezQt
import Nemo.Ssu 1.1 as Ssu

Page {
    id: root

    property QtObject adapter: _bluetoothManager.usableAdapter

    property bool _autoStartDiscovery
    readonly property QtObject _bluetoothManager: BluezQt.Manager
    readonly property bool _bluetoothPoweredOn: btTechModel.available && btTechModel.powered && adapter && adapter.powered
    property int _baseStackDepth: -1

    function _connectToDevice(btDevice) {
        var pendingCall = btDevice.connectToDevice()
        pendingCall.userData = btDevice.address
        devicePicker.addConnectingDevice(btDevice.address)
        pendingCall.finished.connect(function(call) {
            devicePicker.removeConnectingDevice(call.userData)
        })
    }

    function autoStartDiscovery() {
        _autoStartDiscovery = true
        _checkAutoStartDiscovery()
    }

    function _checkAutoStartDiscovery() {
        if (_autoStartDiscovery) {
            if (btTechModel.available && !btTechModel.powered) {
                btTechModel.powered = true
                bluetoothSwitch.busy = true
            } else if (adapter && !adapter.discovering) {
                adapter.startDiscovery()
            }
        }
    }

    onStatusChanged: {
        if (status == PageStatus.Activating) {
            adapterConn._reloadVisibility()
        } else if (status == PageStatus.Active) {
            if (_baseStackDepth < 1) {
                _baseStackDepth = pageStack.depth
                session.holdSession()
            }
        } else if (status == PageStatus.Inactive) {
            if (_baseStackDepth >= 0 && pageStack.depth < _baseStackDepth) {
                if (adapter && adapter.discovering) {
                    adapter.stopDiscovery()
                }
                session.releaseSession()
                _baseStackDepth = -1
            }
        }
    }

    onAdapterChanged: {
        if (adapter) {
            adapterConn._reloadVisibility()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: switchColumn.height + settingsColumn.height
        visible: btTechModel.available

        VerticalScrollDecorator {}

        PullDownMenu {
            visible: (adapter && adapter.powered)
                    || active   // don't hide menu until it has closed

            MenuItem {
                text: adapter && adapter.discovering
                        //: Stop bluetooth device discovery
                        //% "Stop searching"
                      ? qsTrId("settings_bluetooth-me-stop_searching")
                        //: Start bluetooth device discovery
                        //% "Search for devices"
                      : qsTrId("settings_bluetooth-me-search-for-devices")

                onDelayedClick: {
                    if (adapter && adapter.discovering) {
                        adapter.stopDiscovery()
                    } else {
                        adapter.startDiscovery()
                    }
                }
            }
        }

        BluetoothViewPlaceholder {
            id: bluetoothViewPlaceholder
            enabled: !btTechModel.available && root.status === PageStatus.Active
        }

        Column {
            id: switchColumn
            width: parent.width

            PageHeader {
                //% "Bluetooth"
                title: qsTrId("settings_bluetooth-he-bluetooth")
            }

            IconTextSwitch {
                id: bluetoothSwitch

                automaticCheck: false
                checked: root._bluetoothPoweredOn
                //% "Bluetooth"
                text: qsTrId("settings_bluetooth-la-bluetooth")
                icon.source: "image://theme/icon-m-bluetooth"

                onCheckedChanged: {
                    busy = false
                }
                onClicked: {
                    btTechModel.powered = !btTechModel.powered
                    busy = true
                }
            }
        }

        Column {
            id: settingsColumn

            anchors.top: switchColumn.bottom
            width: parent.width

            opacity: enabled ? 1 : 0
            enabled: root._bluetoothPoweredOn

            Behavior on opacity { FadeAnimation { } }

            TextField {
                id: deviceNameField
                width: parent.width

                //: Name of bluetooth device
                //% "Device Name"
                label: qsTrId("settings_bluetooth-la-device_name")

                // Show default name as hint when no text is entered. Don't do this when adapter is
                // unavailable to avoid confusion if the name normally has a non-default value.
                placeholderText: adapter ? Ssu.DeviceInfo.displayName(Ssu.DeviceInfo.DeviceModel) : ""

                //Make sure there's adapter. If adapter use adapter name. If no adapter name use ssu name.
                text: adapter ? (adapter.name ? adapter.name : adapter.name = Ssu.DeviceInfo.displayName(Ssu.DeviceInfo.DeviceModel)) : ""

                onActiveFocusChanged: {
                    if (!activeFocus && adapter) {
                        var newName = text.length ? text : Ssu.DeviceInfo.displayName(Ssu.DeviceInfo.DeviceModel)
                        if (adapter.name != newName) {
                            adapter.name = newName
                        } else {
                            // Text was the default name, then cleared, so reset the displayed text.
                            text = adapter.name
                        }
                    }
                }

                EnterKey.onClicked: root.focus = true
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
            }

            BluetoothVisibilityComboBox {
                id: discoverableCombo

                // To prevent short flash for bluetooth visibility when powering bluetooth off
                opacity: enabled ? 1 : 0
                enabled: root._bluetoothPoweredOn

                onDiscoverableSettingChanged: {
                    if (!adapter) {
                        return
                    }
                    if (timeout < 0) {
                        adapter.discoverable = false
                    } else {
                        adapter.discoverableTimeout = timeout
                        adapter.discoverable = true
                    }
                }
            }

            BluetoothDevicePicker {
                id: devicePicker
                width: parent.width
                highlightSelectedDevice: false
                showPairedDevicesHeader: true

                onDeviceClicked: {
                    if (!adapter || !adapter.powered || selectedDevice === "") {
                        return
                    }
                    var deviceObj = _bluetoothManager.deviceForAddress(selectedDevice)
                    if (!deviceObj) {
                        return
                    }
                    requirePairing = true
                    if (deviceObj.connected) {
                        requirePairing = false
                        deviceObj.disconnectFromDevice()
                    } else {
                        if (deviceObj.paired) {
                            root._connectToDevice(deviceObj)
                        }
                    }
                }

                Timer {
                    id: resetDeviceSelection
                    interval: 100
                    onTriggered: devicePicker.selectedDevice = ""
                }
            }
        }
    }

    Connections {
        id: adapterConn
        target: root.adapter

        function _reloadVisibility() {
            if (root.adapter) {
                discoverableCombo.loadVisibility(root.adapter.discoverable, root.adapter.discoverableTimeout)
            }
        }

        onDiscoverableChanged: {
            _reloadVisibility()
        }
        onDiscoverableTimeoutChanged: {
            _reloadVisibility()
        }
        onDiscoveringChanged: {
            root._autoStartDiscovery = false
        }
        onPoweredChanged: {
            root._checkAutoStartDiscovery()
        }
    }

    BluetoothSession {
        id: session
    }

    TechnologyModel {
        id: btTechModel
        name: "bluetooth"

        // The bluezqt adapter is not available immediately; need to wait until the next event loop.
        onAvailableChanged: delayedAutoDiscoveryTimer.start()
        onPoweredChanged: delayedAutoDiscoveryTimer.start()
    }

    Timer {
        id: delayedAutoDiscoveryTimer
        onTriggered: root._checkAutoStartDiscovery()
    }
}
