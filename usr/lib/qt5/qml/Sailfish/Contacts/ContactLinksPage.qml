import QtQuick 2.0
import Sailfish.Silica 1.0
import Sailfish.Contacts 1.0 as SailfishContacts
import org.nemomobile.contacts 1.0

Page {
    id: root

    property Person person
    property var peopleModel

    property var _peopleModel: peopleModel || SailfishContacts.ContactModelCache.unfilteredModel()
    property bool _pendingLinkOperation
    property bool _fetchedConstituents
    property bool _fetchedMergeCandidates

    property var _aggregationIds
    property var _disaggregationIds

    function _addContactIdsToModel(contactIds, model) {
        for (var i=0; i<contactIds.length; i++) {
            var p = _peopleModel.personById(contactIds[i])
            if (p == null) {
                console.log("Cannot load person for id:", contactIds[i])
                continue
            }
            model.append({"person": p})
        }
    }

    function _aggregate(otherPerson) {
        if (otherPerson.id == person.id) {
            console.log("Cannot aggregate person with self")
        } else {
            otherPerson.aggregateInto(person)
            _pendingLinkOperation = true
        }
    }

    function _disaggregate(otherPerson) {
        var constituents = root.person.constituents
        if (!constituents || constituents.length < 2) {
            console.log("Cannot disaggregate without constituents")
        } else {
            for (var i = 0; i < constituents.length; ++i) {
                if (otherPerson.id == constituents[i]) {
                    otherPerson.disaggregateFrom(person)
                    _pendingLinkOperation = true
                    return
                }
            }
            console.log("Cannot disaggregate person that is not a constituent")
        }
    }

    function _tryAggregateContact() {
        if (_aggregationIds && _aggregationIds.length) {
            var id = _aggregationIds[0]
            _aggregationIds.splice(0, 1)
            _aggregate(_peopleModel.personById(id))
            return true
        }
        return false
    }

    function _tryDisaggregateContact() {
        if (_disaggregationIds && _disaggregationIds.length) {
            var id = _disaggregationIds[0]
            _disaggregationIds.splice(0, 1)
            _disaggregate(_peopleModel.personById(id))
            return true
        }
        return false
    }

    function _applyAllPendingChanges() {
        if (!_tryDisaggregateContact()) {
            _tryAggregateContact()
        }
    }

    onPersonChanged: {
        person.fetchConstituents()
        person.fetchMergeCandidates()
    }

    onStatusChanged: {
        if (status == PageStatus.Deactivating) {
            _applyAllPendingChanges()
        }
    }

    ListModel {
        id: constituentsModel
    }

    ListModel {
        id: mergeCandidatesModel
    }

    Connections {
        target: root.person

        onConstituentsChanged: {
            root._fetchedConstituents = true
            constituentsModel.clear()
            root._addContactIdsToModel(root.person.constituents, constituentsModel)

            if (status == PageStatus.Active) {
                // Update the possible merge candidates
                root.person.fetchMergeCandidates()
            }
        }

        onAggregationOperationFinished: {
            // this signal is emitted twice for each link operation, so avoid unnecessary calls
            // to fetchConstituents()
            root._fetchedMergeCandidates = true
            if (root._pendingLinkOperation) {
                root._pendingLinkOperation = false
                // If we have any pending disaggregations, process them
                if (!_tryDisaggregateContact()) {
                    // If we have any pending aggregations, process them
                    if (!_tryAggregateContact()) {
                        // Fetch the updated constituent/candidate data
                        root.person.fetchConstituents()
                    }
                }
            }
        }

        onMergeCandidatesChanged: {
            mergeCandidatesModel.clear()
            root._addContactIdsToModel(root.person.mergeCandidates, mergeCandidatesModel)
        }
    }

    Column {
        anchors.centerIn: parent
        visible: busyIndicator.running
        spacing: Theme.paddingLarge

        Label {
            width: root.width - Theme.horizontalPageMargin*2
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.highlightColor

            //: Displayed while the page is in the process of loading links (i.e. associated contacts with similar details)
            //% "Finding links..."
            text: qsTrId("components_contacts-la-finding_links")
        }

        BusyIndicator {
            id: busyIndicator
            anchors.horizontalCenter: parent.horizontalCenter
            size: BusyIndicatorSize.Large
            running: !root._fetchedConstituents && !root._fetchedMergeCandidates
        }
    }

    SilicaListView {
        anchors.fill: parent
        visible: !busyIndicator.running

        PullDownMenu {
            MenuItem {
                //: Allows user to choose more contacts to be linked to this one
                //% "Add more links"
                text: qsTrId("components_contacts-me-add_links")
                onClicked: {
                    var obj = pageStack.animatorPush(Qt.resolvedUrl("ContactsMultiSelectDialog.qml"))
                    obj.pageCompleted.connect(function(picker) {

                        picker.accepted.connect(function() {
                            for (var i=0; i<picker.selectedContacts.count; i++) {
                                var id = picker.selectedContacts.get(i)
                                if (root._aggregationIds === undefined) {
                                    root._aggregationIds = [ id ]
                                } else {
                                    root._aggregationIds.push(id)
                                }
                            }
                            _tryAggregateContact()
                        })
                    })
                }
            }
        }

        header: Column {
            id: contentColumn
            width: parent.width

            PageHeader {
                //: Header for page enabling management of links (associated contacts with similar details) for this contact
                //% "Links"
                title: qsTrId("components_contacts-he-links")
            }

            Column {
                Repeater {
                    width: parent.width
                    model: constituentsModel
                    delegate: ContactLinkItem {
                        enabled: constituentsModel.count > 1
                        onClicked: {
                            animateRemoval()  // animate before removal to avoid waiting for model to update

                            if (root._disaggregationIds === undefined) {
                                root._disaggregationIds = [ model.person.id ]
                            } else {
                                root._disaggregationIds.push(model.person.id)
                            }

                            _tryDisaggregateContact()
                        }
                    }
                }
            }

            SectionHeader {
                //: List of suggestions for contacts that could be linked to this one as they have similar details
                //% "Link suggestions"
                text: qsTrId("components_contacts-la-link_suggestions")
            }
        }

        model: mergeCandidatesModel
        delegate: ContactLinkItem {
            onClicked: {
                animateRemoval()  // animate before removal to avoid waiting for model to update

                if (root._aggregationIds === undefined) {
                    root._aggregationIds = [ model.person.id ]
                } else {
                    root._aggregationIds.push(model.person.id)
                }

                _applyAllPendingChanges()
            }
        }
        VerticalScrollDecorator {}
    }
}
