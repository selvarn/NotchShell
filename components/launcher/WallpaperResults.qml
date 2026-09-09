import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../core"
import "../../services"
import "../primitives"

// Wallpapers: the names on the left, one large preview on the right.
//
// Nothing is applied while you look. Moving the selection only changes the
// preview inside this sheet — `wal --backend schemer2` takes hundreds of
// milliseconds and repaints every colour in the system, so running it per
// arrow key would turn browsing into a strobe. Choosing is the commit.
Item {
    id: view

    property bool active: false
    // Height of the screen this sheet is on. awww measures its transition
    // origin from the bottom edge, and only the window knows where that is.
    property real screenHeight: 0

    readonly property var results: Wallpapers.search(Launcher.query)
    readonly property bool empty: results.length === 0
    readonly property var chosen: results[Launcher.index] || null

    onResultsChanged: if (active)
        Launcher.count = results.length
    onActiveChanged: if (active) {
        Launcher.count = results.length;
        Launcher.index = 0;
    }

    // px/py are screen coordinates for the transition's origin, in awww's
    // frame (y measured from the bottom). Called with the pointer position
    // for a click, and with the preview's own centre for a keypress — either
    // way the new wallpaper grows out of the thing that was just looked at.
    function apply(px, py) {
        if (!chosen)
            return;
        Wallpapers.apply(chosen.path, px, py);
        Launcher.hide();
    }

    function activate() {
        if (!chosen)
            return;
        var c = previewPane.mapToItem(null, previewPane.width / 2, previewPane.height / 2);
        view.apply(c.x, view.screenHeight - c.y);
    }

    // ── empty state ─────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: view.empty

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.image
            size: 18
            color: Theme.textFaint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Wallpapers.all.length === 0 ? "No wallpapers in " + Wallpapers.dir : "No wallpapers match"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 12
            elide: Text.ElideMiddle
            width: view.width - 40
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── the list ────────────────────────────────────────────────
    ListView {
        id: list
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 8
        width: Config.launcherWallListWidth - Config.railHitWidth
        visible: !view.empty
        clip: true
        model: view.results
        currentIndex: Launcher.index
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            id: row

            required property int index
            required property var modelData

            readonly property bool selected: index === Launcher.index
            readonly property bool isCurrent: Wallpapers.current === modelData.path

            width: list.width
            height: 34

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

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: mark.left
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                color: row.selected ? Theme.accent : Theme.textSecondary
                font.family: Theme.fontSans
                font.pixelSize: 12
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideMiddle
            }

            // The one that is already on screen.
            Icon {
                id: mark
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                box: row.isCurrent ? Math.round(10 * Config.iconBoxScale) : 0
                visible: row.isCurrent
                text: Icons.check
                size: 10
                color: Theme.accent
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Movement, not arrival — see Launcher.hoverAt.
                onPositionChanged: mouse => Launcher.hoverAt(row.index, mapToItem(null, mouse.x, mouse.y))
                onEntered: Launcher.hoverAt(row.index, mapToItem(null, mouseX, mouseY))
                onClicked: mouse => {
                    Launcher.index = row.index;
                    var p = mapToItem(null, mouse.x, mouse.y);
                    view.apply(p.x, view.screenHeight - p.y);
                }
            }
        }
    }

    ScrollRail {
        anchors.left: list.right
        anchors.top: list.top
        anchors.bottom: list.bottom
        flickable: list
    }

    // ── the preview ─────────────────────────────────────────────
    Item {
        id: previewPane
        anchors.left: list.right
        // Wide enough that the corner mask below has clean panel to sit on.
        anchors.leftMargin: Config.railHitWidth + 10
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        visible: !view.empty

        // ── rounded corners, without ClippingRectangle ──────────
        //
        // Quickshell's ClippingRectangle clips through a ShaderEffectSource,
        // and on a large WIDE item holding an image this build gets the mask's
        // horizontal mapping wrong: the right-hand corners round and the
        // left-hand ones stay square. (Square items are fine — which is why
        // the media card's album art has always looked right.)
        //
        // So the corners are cut the other way round: the image is drawn
        // square and a ring of panel colour, following a rounded outline, is
        // laid over its edge. Only the four corner arcs actually fall inside
        // the image; the rest of the ring lands on the panel it matches. No
        // render target, no shader, and nothing to get the aspect wrong.
        readonly property real maskWidth: 8

        Image {
            id: shot
            anchors.fill: parent
            source: view.chosen ? view.chosen.url : ""
            // Downscaled on load: these are full desktop wallpapers, and
            // decoding sixteen of them at native size to draw one at
            // 430 px would cost more memory than the whole shell.
            sourceSize.width: 860
            fillMode: Image.PreserveAspectCrop
            // PreserveAspectCrop paints outside the item unless told not to.
            clip: true
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            visible: status === Image.Ready
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Config.contentFadeDur; easing.type: Config.easeFade }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !shot.visible
            radius: Config.rMd
            antialiasing: true
            color: Theme.sunken

            Icon {
                anchors.centerIn: parent
                text: Icons.image
                size: 20
                color: Theme.textFaint
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -previewPane.maskWidth
            radius: Config.rMd + previewPane.maskWidth
            color: "transparent"
            border.width: previewPane.maskWidth
            border.color: Theme.panel
            antialiasing: true
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                var p = mapToItem(null, mouse.x, mouse.y);
                view.apply(p.x, view.screenHeight - p.y);
            }
        }
    }
}
