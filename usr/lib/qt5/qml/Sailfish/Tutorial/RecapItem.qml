/*
 * Copyright (c) 2014 - 2019 Jolla Ltd.
 *
 * License: Proprietary
 */

import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Tutorial 1.0

SilicaItem {
    id: root
    anchors.fill: parent
    opacity: 0.0

    property int completedLessons
    property bool buttonsEnabled: showAnimation.running || root.opacity === 1.0
    property bool upgradeMode

    property string descriptionText

    property int retryLessonIndex

    function show(pauseDuration) {
        showPause.duration = pauseDuration !== undefined ? pauseDuration : 500
        if (lessonCounter === 0) {
            if (upgradeMode) {
                //: The primary label shown when the tutorial is show after an upgrade
                //% "Congratulations on upgrading to Sailfish OS 2.0!"
                label.text = qsTrId("tutorial-la-thanks_for_updating")
            } else {
                //: The primary label shown when the tutorial is started
                //% "Learn basics of Sailfish OS"
                label.text = qsTrId("tutorial-la-learn_basics")
            }
            againButton.visible = false
            //% "Start"
            continueButton.text = qsTrId("tutorial-bt-start")
        } else {
            //% "Well done!"
            label.text = qsTrId("tutorial-la-well_done")
            againButton.visible = true
            continueButton.text = lessonCounter === maxLessons
                    //: The button text shown at the end of the tutorial. Pressing this quits the tutorial.
                    //% "Close tutorial"
                    ? qsTrId("tutorial-bt-close_tutorial")
                    //% "Continue"
                    : qsTrId("tutorial-bt-continue")
            completedLessons = lessonCounter
        }

        description.text = descriptionText

        showAnimation.restart()
    }

    SequentialAnimation {
        id: showAnimation
        PauseAnimation { id: showPause }
        FadeAnimation {
            target: root
            property: "opacity"
            to: 1.0
            duration: 1000
        }
        ScriptAction {
            script: {
                if (allowSystemGesturesBetweenLessons) {
                    __quickWindow.flags &= ~(Qt.WindowOverridesSystemGestures)
                }
            }
        }
    }

    SequentialAnimation {
        id: hideAnimation
        ScriptAction {
            script: {
                if (allowSystemGesturesBetweenLessons) {
                    __quickWindow.flags |= Qt.WindowOverridesSystemGestures
                }
            }
        }
        FadeAnimation {
            target: root
            property: "opacity"
            to: 0.0
            duration: 1000
        }
        ScriptAction { script: showLesson() }
    }

    Rectangle {
        anchors.fill: parent
        color: root.palette.highlightDimmerColor
        opacity: 0.9
    }

    InfoLabel {
        id: label
        y: Math.round(Screen.height/7)
    }

    Label {
        id: description
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        x: Theme.horizontalPageMargin
        anchors {
            top: label.bottom
            topMargin: Theme.paddingLarge
        }
        width: parent.width - 2 * x
        textFormat: Text.PlainText
    }

    CornerTapItem {
        id: cornerTap
        anchors.fill: parent
        onTriggered: Qt.quit()
    }

    IconButton {
        anchors {
            top: parent.top
            right: parent.right
            margins: Theme.paddingLarge
        }

        visible: allowSystemGesturesBetweenLessons
        icon.source: "image://theme/icon-m-clear"

        onClicked: Qt.quit()
    }

    Connections {
        target: mainPage
        onLessonCounterChanged: cornerTap.reset()
    }

    ButtonLayout {
        anchors {
            bottom: progress.top
            bottomMargin: 4*Theme.paddingLarge
        }
        preferredWidth: Theme.buttonWidthMedium
        Button {
            id: againButton
            enabled: buttonsEnabled
            //% "Try again"
            text: qsTrId("tutorial-bt-try_again")

            onClicked: {
                lessonCounter = retryLessonIndex
                hideAnimation.restart()
            }
        }
        Button {
            id: continueButton
            ButtonLayout.newLine: true
            enabled: buttonsEnabled

            onClicked: {
                lessonCounter++
                retryLessonIndex = lessonCounter
                hideAnimation.restart()
            }
        }
    }

    Row {
        id: progress

        anchors {
            bottom: parent.bottom
            bottomMargin: 3 * Theme.paddingLarge
            horizontalCenter: parent.horizontalCenter
        }
        spacing: Theme.paddingMedium
        visible: completedLessons > 0

        Repeater {
            model: maxLessons
            HighlightImage {
                source: "image://theme/graphic-tutorial-progress-" + (index + 1)
                opacity: (completedLessons > index) ? 1.0 : Theme.opacityHigh
                highlighted: true
            }
        }
    }
}
