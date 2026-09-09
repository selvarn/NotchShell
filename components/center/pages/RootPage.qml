import QtQuick
import "../../../"
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

// The Command Center's home screen: clock + player, the one thing that is
// genuinely a value (volume), and the tile grid.
//
// Controls are not all one shape on purpose. A value gets a slider, a binary
// state gets a tile whose badge toggles it in place, and anything with more
// to say also drills down. Nothing here needs a sub-page just to be switched
// on or off.
//
// Tiles hide themselves when the machine can't do the thing, so the grid
// reflows on its own as hardware or packages appear — nothing shows a dead
// control, and nothing offers a quick action it cannot actually perform.
Item {
    id: page

    implicitHeight: col.implicitHeight
    readonly property real tileWidth: (width - Config.gap) / 2

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        // ── clock + media ───────────────────────────────────────
        Reveal {
            index: 0
            width: parent.width
            height: Config.clockTileSize

            ClockTile {
                id: clock
                anchors.left: parent.left
                anchors.top: parent.top
            }
            MediaCard {
                anchors.left: clock.right
                anchors.leftMargin: Config.gap
                anchors.right: parent.right
                anchors.top: parent.top
            }
        }

        // ── master volume ───────────────────────────────────────
        Reveal {
            index: 1
            width: parent.width
            height: Config.sliderHeight

            SliderRow {
                anchors.fill: parent
                glyph: Audio.volume > 0.5 ? Icons.volumeHigh : Icons.volumeLow
                glyphOff: Icons.volumeMute
                value: Audio.volume
                off: Audio.muted
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
        }

        // ── tiles ───────────────────────────────────────────────
        Reveal {
            index: 2
            width: parent.width
            height: grid.implicitHeight

            Grid {
                id: grid
                width: parent.width
                columns: 2
                spacing: Config.gap

                ControlTile {
                    width: page.tileWidth
                    glyph: Net.vpnActive ? Icons.vpn : Net.isWifi ? Icons.wifi : Net.connected ? Icons.ethernet : Icons.globe
                    label: "Network"
                    sublabel: Net.summary
                    active: Net.connected || Net.vpnActive
                    drill: true
                    // A quick action only where there is an honest one to
                    // offer: a VPN profile NetworkManager can bring back up
                    // after switching it off. Nothing else on this tile is
                    // safe to toggle blind.
                    quick: Net.togglableVpn !== null
                    onToggled: Net.toggleVpn()
                    onOpened: CenterNav.go("network")
                }
                ControlTile {
                    width: page.tileWidth
                    glyph: Audio.muted ? Icons.volumeMute : Icons.headphones
                    label: "Audio"
                    sublabel: Audio.muted ? "Muted" : Audio.sinkLabel
                    active: !Audio.muted
                    drill: true
                    quick: Audio.ready
                    onToggled: Audio.toggleMute()
                    onOpened: CenterNav.go("audio")
                }
                ControlTile {
                    width: page.tileWidth
                    visible: NightLight.available
                    glyph: Icons.moon
                    label: "Night Light"
                    sublabel: NightLight.summary
                    active: NightLight.enabled
                    busy: NightLight.busy
                    drill: true
                    quick: true
                    onToggled: NightLight.toggle()
                    onOpened: CenterNav.go("nightlight")
                }
                ControlTile {
                    width: page.tileWidth
                    glyph: Notify.paused ? Icons.bellOff : Icons.bell
                    label: Notify.paused ? "Do Not Disturb" : "Notifications"
                    sublabel: Notify.paused ? "Silenced" : (Notify.historyCount + " in history")
                    active: Notify.paused
                    drill: true
                    quick: Notify.available
                    onToggled: Notify.toggle()
                    onOpened: CenterNav.go("notifications")
                }
                ControlTile {
                    width: page.tileWidth
                    glyph: Icons.power
                    label: "Power"
                    sublabel: "Session"
                    drill: true
                    onOpened: CenterNav.go("power")
                }
            }
        }
    }
}
