import QtQuick
import Quickshell.Widgets
import "../../"
import "../../core"
import "../../services"
import "../primitives"

// The player: artwork, track, a scrubbable timeline and transport — one of
// the two anchors of the Command Center's top row.
//
// The timeline is the part with opinions. It is a *scrubber*, not a
// read-only bar:
//
//   • the hit target is the full height of the row, not the 4 px of drawn
//     track, so it can be grabbed without aiming;
//   • pressing starts a drag and the fill follows the pointer immediately,
//     while the actual seek is sent once, on release — dragging a scrubber
//     that seeks per frame makes a player stutter and fight back;
//   • while dragging, the readout shows where you are *going*, and Media
//     holds that position over the player's own for a moment after release
//     so the bar never snaps back to the old spot and then jumps forward.
//
// It also never lets a press through to the click-away scrim behind the
// sheet — see CommandCenter, which swallows stray clicks for every child.
SoftCard {
    id: card

    raised: true
    radius: Config.rLg
    implicitHeight: Config.clockTileSize

    readonly property bool has: Media.available

    // ── empty state ─────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: 6
        visible: !card.has
        opacity: card.has ? 0 : 1
        Behavior on opacity {
            NumberAnimation { duration: Config.contentFadeDur }
        }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Icons.music
            size: 20
            color: Theme.textFaint
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nothing playing"
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 12
        }
    }

    // ── player ──────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: 12
        visible: card.has
        opacity: card.has ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Config.contentFadeDur }
        }

        // Artwork, with a glyph placeholder when the player exposes none.
        //
        // ClippingRectangle, not a Rectangle with `clip: true`: a plain
        // Rectangle clips to its bounding box, so a rounded card still
        // showed square cover art poking into all four corners. This one
        // clips to the rounded outline itself.
        ClippingRectangle {
            id: art
            width: 52
            height: 52
            radius: Config.rSm
            antialiasing: true
            color: Theme.sunken

            Icon {
                anchors.centerIn: parent
                text: Icons.music
                size: 17
                color: Theme.textFaint
                visible: cover.status !== Image.Ready
            }

            Image {
                id: cover
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true
                visible: status === Image.Ready
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.top: art.top
            anchors.topMargin: 4
            spacing: 3

            Text {
                width: parent.width
                text: Media.title.length ? Media.title : Media.appName
                color: Theme.textPrimary
                font.family: Theme.fontSans
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                width: parent.width
                text: Media.artist.length ? Media.artist : Media.appName
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // ── timeline ────────────────────────────────────────────
        Item {
            id: seek

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: transport.top
            anchors.bottomMargin: 4
            // Tall enough that the hover region, the grab region and the
            // drawn track are all the same rectangle — a bar that thickens
            // on hover but is only grabbable on the thin part is worse than
            // one that never moves at all.
            height: 18
            visible: Media.hasLength

            property bool scrubbing: false
            property real scrubValue: 0

            // What the fill draws: the drag while there is one, the player
            // otherwise. One property, so the two can never disagree.
            readonly property real shown: scrubbing ? scrubValue : Media.progress
            // Thickened and given a handle while it is in play, so a bar
            // that is only being read stays a hairline.
            readonly property bool engaged: (hover.hovered || scrubbing) && Media.canSeek

            function fractionAt(mx) {
                return width > 0 ? Config.clamp(mx / width, 0, 1) : 0;
            }

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: seek.engaged ? 6 : 4
                radius: height / 2
                antialiasing: true
                color: Theme.sunken

                Behavior on height {
                    NumberAnimation { duration: 120; easing.type: Config.easeFade }
                }

                Rectangle {
                    id: fill
                    width: parent.width * Config.clamp(seek.shown, 0, 1)
                    height: parent.height
                    radius: parent.radius
                    antialiasing: true
                    color: Theme.accent
                    // Deliberately no Behavior: Media pulls the position at
                    // frame rate, so this is already a sweep, and an
                    // animator on top of it would only add lag — and would
                    // make a scrub drag trail behind the pointer.
                }
            }

            Rectangle {
                id: knob
                width: seek.scrubbing ? 12 : 10
                height: width
                radius: width / 2
                antialiasing: true
                color: Theme.accent
                y: (seek.height - height) / 2
                // Clamped to the track, so the handle stays on the rail at
                // both ends instead of hanging half off it.
                x: Config.clamp(track.width * Config.clamp(seek.shown, 0, 1) - width / 2, 0, Math.max(0, track.width - width))
                opacity: seek.engaged ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Config.easeFade }
                }
                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
            }

            HoverHandler {
                id: hover
            }

            MouseArea {
                id: scrubber
                // The drawn track is 4 px; the grab is the whole row.
                anchors.fill: parent
                preventStealing: true
                cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

                onPressed: mouse => {
                    if (!Media.canSeek)
                        return;
                    seek.scrubbing = true;
                    seek.scrubValue = seek.fractionAt(mouse.x);
                }
                onPositionChanged: mouse => {
                    if (seek.scrubbing)
                        seek.scrubValue = seek.fractionAt(mouse.x);
                }
                onReleased: {
                    if (!seek.scrubbing)
                        return;
                    seek.scrubbing = false;
                    Media.seekFraction(seek.scrubValue);
                }
                onCanceled: seek.scrubbing = false
            }
        }

        // ── transport ───────────────────────────────────────────
        Row {
            id: transport
            anchors.left: parent.left
            anchors.leftMargin: -6
            anchors.bottom: parent.bottom
            spacing: 2

            IconButton {
                glyph: Icons.prev
                glyphSize: 11
                implicitWidth: 30
                implicitHeight: 30
                enabled: Media.canGoPrevious
                onClicked: Media.previous()
            }
            IconButton {
                glyph: Media.playing ? Icons.pause : Icons.play
                glyphSize: 12
                implicitWidth: 32
                implicitHeight: 32
                filled: true
                enabled: Media.canToggle
                onClicked: Media.toggle()
            }
            IconButton {
                glyph: Icons.next
                glyphSize: 11
                implicitWidth: 30
                implicitHeight: 30
                enabled: Media.canGoNext
                onClicked: Media.next()
            }
        }

        // Elapsed / total, following the drag rather than the player while
        // one is in progress — the readout answers "where will this land",
        // which is the only question being asked mid-scrub.
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: transport.verticalCenter
            visible: Media.hasLength
            text: Media.formatTime(seek.scrubbing ? seek.scrubValue * Media.length : Media.position) + " / " + Media.formatTime(Media.length)
            color: seek.scrubbing ? Theme.textPrimary : Theme.textMuted
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }
}
