import QtQuick
import "../../services"
import "../primitives"
import "../../core"

// Keyboard layout, shown as a two-position switch rather than a label.
// Only the short codes appear — "en" / "ru", lowercase, nothing else — and
// the active highlight physically travels between them instead of one code
// vanishing while the other appears.
Item {
    id: root

    property var payload: ({})
    readonly property string code: (payload && payload.code) ? payload.code : Hypr.layoutCode

    implicitWidth: control.implicitWidth
    implicitHeight: control.implicitHeight

    SegmentedControl {
        id: control
        anchors.centerIn: parent
        items: Hypr.layoutCodes
        currentIndex: Math.max(0, Hypr.layoutCodes.indexOf(root.code))
        segWidth: 38
        segHeight: 24
        fontSize: 12
        onSegmentClicked: index => {
            if (index !== control.currentIndex)
                Hypr.cycleLayout();
        }
    }
}
