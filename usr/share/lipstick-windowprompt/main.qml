/****************************************************************************
**
** Copyright (C) 2017 Jolla Ltd.
** Contact: Bea Lam <bea.lam@jollamobile.com>
**
****************************************************************************/

import QtQuick 2.0
import QtQuick.Window 2.0
import Sailfish.Silica 1.0
import com.jolla.lipstick 0.1

ApplicationWindow {
    id: root

    property var _promptWindow
    property var _promptConfigQueue: []

    function _showPrompt(promptConfig) {
        if (!_promptWindow) {
            var comp = Qt.createComponent(Qt.resolvedUrl(promptConfig.componentName))
            if (comp.status == Component.Error) {
                console.log(promptConfig.componentName, "error:", comp.errorString())
                return
            }
            _promptWindow = comp.createObject(root)
            _promptWindow.done.connect(_promptDone)
        }
        _promptWindow.init(promptConfig)
    }

    function _promptDone(window, unregister) {
        if (unregister)
            manager.unregisterTerms(window.promptConfig)
        window.lower()
        delayedQuit.restart()
    }

    function _queueOrShowPrompt(promptConfig) {
        if (_promptWindow && _promptWindow.windowVisible) {
            _promptConfigQueue.push(promptConfig)
        } else {
            _showPrompt(promptConfig)
        }
    }

    allowedOrientations: defaultAllowedOrientations
    _defaultPageOrientations: Orientation.All
    _defaultLabelFormat: Text.PlainText
    cover: undefined

    WindowPromptManager {
        id: manager

        onShowTermsPromptUi: {
            // Register the terms/agreement so that lipstick knows to re-display the dialog on
            // startup hasn't yet been accepted (e.g. if rebooted without accepting it).

            if (!promptConfig.componentName) {
                promptConfig.componentName = "TermsPromptWindow.qml"
            }

            if (manager.registerTerms(promptConfig)) {
                _queueOrShowPrompt(promptConfig)
            } else {
                console.log("showTermsPrompt() failed, cannot register config", termsId(promptConfig))
                if (!_promptWindow || !_promptWindow.windowVisible) {
                    Qt.quit()
                }
            }
        }

        onStorageDeviceUi: {
            if (!promptConfig.componentName) {
                promptConfig.componentName = "StorageDeviceSystemDialog.qml"
            }

            _queueOrShowPrompt(promptConfig)
        }
    }

    Timer {
        id: delayedQuit
        interval: 400   // wait for window fade outs etc.
        onTriggered: {
            if (_promptConfigQueue.length > 0) {
                _showPrompt(_promptConfigQueue.pop())
            } else {
                console.log("lipstick-windowprompt: exiting...")
                Qt.quit()
            }
        }
    }
}
