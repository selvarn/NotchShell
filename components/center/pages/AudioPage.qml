import QtQuick
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

// Audio drill-down: output and input levels, then device selection.
Item {
    id: page
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        PageHeader {
            width: parent.width
            title: "Audio"
        }

        SliderRow {
            width: parent.width
            glyph: Audio.volume > 0.5 ? Icons.volumeHigh : Icons.volumeLow
            glyphOff: Icons.volumeMute
            value: Audio.volume
            off: Audio.muted
            onMoved: v => Audio.setVolume(v)
            onIconClicked: Audio.toggleMute()
        }

        SliderRow {
            width: parent.width
            glyph: Icons.mic
            glyphOff: Icons.micMute
            value: Audio.micVolume
            off: Audio.micMuted
            onMoved: v => Audio.setMicVolume(v)
            onIconClicked: Audio.toggleMicMute()
        }

        Text {
            text: "Output"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }

        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: Audio.sinks
                delegate: ListRow {
                    required property var modelData
                    width: col.width
                    glyph: Icons.headphones
                    label: Audio.nodeLabel(modelData)
                    selected: modelData === Audio.currentSink
                    onActivated: Audio.setSink(modelData)
                }
            }
        }

        Text {
            text: "Input"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.8
        }

        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: Audio.sources
                delegate: ListRow {
                    required property var modelData
                    width: col.width
                    glyph: Icons.mic
                    label: Audio.nodeLabel(modelData)
                    selected: modelData === Audio.currentSource
                    onActivated: Audio.setSource(modelData)
                }
            }
        }
    }
}
