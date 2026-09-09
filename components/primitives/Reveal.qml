import QtQuick
import "../../core"

// Wraps one row of Command Center content so it fades and rises very
// slightly into place as the sheet opens, staggered by `index`.
//
// The rise is a render-time transform (never a layout change) and it is only
// ~10 px, so with the sheet's clip the content always appears from *inside*
// the panel rather than sliding in from outside it.
Item {
    id: rev

    property int index: 0
    property real amount: UiState.expandFraction
    property real rise: 10

    readonly property real t: Config.stagger(index, amount)

    opacity: t
    visible: opacity > 0.01

    transform: Translate {
        y: (1 - rev.t) * rev.rise
    }
}
