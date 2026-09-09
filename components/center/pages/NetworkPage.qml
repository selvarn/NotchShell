import QtQuick
import "../../../core"
import "../../../services"
import "../../primitives"
import ".."

// Network drill-down: what is up right now, then every NetworkManager
// connection. Externally managed tunnels are listed read-only and say so —
// NM can take them down but only the application that opened them can bring
// them back, so offering a toggle would be a trap. See services/Net.qml.
Item {
    id: page
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        PageHeader {
            width: parent.width
            title: "Network"
        }

        ListRow {
            width: parent.width
            glyph: Net.vpnActive ? Icons.vpn : Net.isWifi ? Icons.wifi : Net.connected ? Icons.ethernet : Icons.globe
            label: Net.connected ? Net.primaryName : "Offline"
            sublabel: Net.vpnActive ? "VPN active · " + Net.vpnName : (Net.connected ? Net.primaryType : "No active connection")
            selected: Net.connected
            enabled: false
        }

        Text {
            text: "Connections"
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
                model: Net.connections
                delegate: ListRow {
                    required property var modelData
                    width: col.width
                    glyph: modelData.type === "tun" || modelData.type === "vpn" || modelData.type === "wireguard" ? Icons.vpn : modelData.type.indexOf("wireless") !== -1 ? Icons.wifi : Icons.ethernet
                    label: modelData.name
                    sublabel: modelData.active ? (modelData.external ? "Connected · managed externally" : "Connected") : modelData.type
                    selected: modelData.active
                    enabled: !modelData.external
                    trailingText: modelData.external ? "external" : ""
                    onActivated: Net.toggle(modelData)
                }
            }
        }
    }
}
