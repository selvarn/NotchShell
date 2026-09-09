import QtQuick
import "../../"
import "../../core"

// What the resting notch shows: the time, and nothing else. Deliberately
// sparse, and deliberately plain text — against the pure-black notch any
// chip or outline would read as a separate floating element.
//
// The keyboard layout used to sit at the right edge here. It doesn't any
// more: a layout code is only interesting at the moment it changes, and
// that moment already has a home — the layout transient, which owns the
// notch for its TTL and then leaves. Parking it in the resting peek made a
// permanent label out of a momentary event.
Item {
    id: peek

    Text {
        anchors.centerIn: parent
        text: Clock.time
        color: Theme.textPrimary
        font.family: Theme.fontMono
        font.pixelSize: 15
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
    }
}
