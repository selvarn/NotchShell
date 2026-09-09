import QtQuick
import Quickshell
import "../../"
import "../../core"
import "../../services"
import "../primitives"

// Ranked application results. Rows follow the same idiom as the Command
// Center's ListRow — a quiet card that lifts on hover, accent ink to say
// "this is the one" — so the launcher does not invent a second visual
// language for the same gesture.
Item {
    id: view

    property bool active: false

    readonly property var results: Apps.search(Launcher.query)
    readonly property bool empty: results.length === 0

    // The active view owns the selection bounds. Only the visible one may say
    // so, or the hidden view would fight it for the same property.
    onResultsChanged: if (active)
        Launcher.count = results.length
    onActiveChanged: if (active) {
        Launcher.count = results.length;
        Launcher.index = 0;
    }

    function activate() {
        var e = results[Launcher.index];
        if (!e)
            return;
        Apps.launch(e);
        Launcher.hide();
    }

    // ── empty state ─────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: view.empty

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.search
            size: 18
            color: Theme.textFaint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Apps.ready ? "No applications match" : "Reading applications…"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
    }

    // ── results ─────────────────────────────────────────────────
    ListView {
        id: list
        anchors.fill: parent
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        anchors.leftMargin: 8
        // Room for the rail, which sits over the gutter rather than beside it.
        anchors.rightMargin: 8 + Config.railHitWidth
        visible: !view.empty
        clip: true
        model: view.results
        currentIndex: Launcher.index
        boundsBehavior: Flickable.StopAtBounds
        // Keyboard selection has to drag the viewport with it, or holding
        // Down walks the highlight straight off the bottom of the sheet.
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            id: row

            required property int index
            required property var modelData

            readonly property bool selected: index === Launcher.index

            width: list.width
            height: Config.launcherRowHeight

            Rectangle {
                anchors.fill: parent
                anchors.topMargin: 1
                anchors.bottomMargin: 1
                radius: Config.rSm
                antialiasing: true
                color: row.selected ? Theme.surfaceActive : ma.containsMouse ? Theme.surfaceHover : "transparent"
                Behavior on color {
                    ColorAnimation { duration: 110; easing.type: Config.easeFade }
                }
            }

            // App icon, with a glyph standing in whenever the theme has
            // nothing for this entry — which is common enough that a blank
            // square would look like a bug.
            Item {
                id: iconBox
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 26
                height: 26

                Image {
                    id: appIcon
                    anchors.fill: parent
                    // Asked of the theme *before* loading. Handing the image
                    // provider a name it doesn't have does not fail quietly —
                    // it paints a placeholder square, which looks far more
                    // broken than the glyph this falls back to.
                    source: {
                        var n = row.modelData.icon;
                        if (!n || !n.length)
                            return "";
                        // Some entries name a file rather than a theme icon.
                        if (n.charAt(0) === "/")
                            return "file://" + n;
                        return Quickshell.hasThemeIcon(n) ? Quickshell.iconPath(n) : "";
                    }
                    sourceSize.width: 52
                    sourceSize.height: 52
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    mipmap: true
                    visible: source != "" && status === Image.Ready
                }

                Icon {
                    anchors.centerIn: parent
                    text: row.modelData.terminal ? Icons.terminal : Icons.apps
                    size: 15
                    color: row.selected ? Theme.accent : Theme.textFaint
                    visible: !appIcon.visible
                }
            }

            Column {
                anchors.left: iconBox.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: parent.width
                    text: row.modelData.name
                    color: row.selected ? Theme.accent : Theme.textPrimary
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    width: parent.width
                    text: row.modelData.generic.length ? row.modelData.generic : row.modelData.comment
                    visible: text.length > 0
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Hovering moves the selection, so mouse and keyboard never
                // disagree about which row Enter would launch — but only once
                // the pointer has actually moved. See Launcher.hoverAt.
                onPositionChanged: mouse => Launcher.hoverAt(row.index, mapToItem(null, mouse.x, mouse.y))
                onEntered: Launcher.hoverAt(row.index, mapToItem(null, mouseX, mouseY))
                onClicked: {
                    Launcher.index = row.index;
                    view.activate();
                }
            }
        }
    }

    ScrollRail {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.top: list.top
        anchors.bottom: list.bottom
        flickable: list
    }
}
