import QtQuick
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

// Night Light detail: warmth, and nothing else.
//
// On/off deliberately does not appear here. The toggle lives on the tile in
// the Command Center's root, so the two levels of interaction stay clean —
// the badge switches it, this page tunes it. Duplicating the switch inside
// the detail would give the same state two owners and two places to
// disagree.
//
// Dragging the slider retunes the *running* daemon over its control socket,
// so the screen warms under the pointer as you move it. Turning night light
// off does not disturb the chosen value, so switching it back on returns to
// the same warmth.
Item {
    id: page
    implicitHeight: col.implicitHeight

    // Warm to the right: dragging toward the warm end raises the fill, which
    // is the direction the effect gets stronger. Both directions of the map
    // live here, next to each other, so they can't drift apart.
    readonly property real span: NightLight.tempMax - NightLight.tempMin
    function toSlider(k) {
        return (NightLight.tempMax - k) / page.span;
    }
    function toKelvin(v) {
        return NightLight.tempMax - v * page.span;
    }

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        PageHeader {
            width: parent.width
            title: "Night Light"
        }

        SliderRow {
            width: parent.width
            // The badge warms with the value it is setting.
            glyph: NightLight.temperature > 5200 ? Icons.sun : Icons.moon
            glyphOff: Icons.moon
            iconToggles: false
            value: page.toSlider(NightLight.temperature)
            valueText: NightLight.temperature + "K"
            off: !NightLight.enabled
            onMoved: v => NightLight.setTemperature(page.toKelvin(v))
        }

        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                text: "Neutral"
                color: Theme.textFaint
                font.family: Theme.fontSans
                font.pixelSize: 10
            }
            Text {
                anchors.right: parent.right
                text: "Warm"
                color: Theme.textFaint
                font.family: Theme.fontSans
                font.pixelSize: 10
            }
        }

        Text {
            width: parent.width
            text: !NightLight.available ? "hyprsunset is not installed" : NightLight.enabled ? "Applied at " + NightLight.temperature + "K" : "Night Light is off — this warmth is kept for next time"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }
}
