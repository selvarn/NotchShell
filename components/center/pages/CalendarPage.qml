import QtQuick
import "../../../"
import "../../../core"
import "../../primitives"
import ".."

// Month view reached by tapping the clock tile. Weeks start on Monday.
Item {
    id: page
    implicitHeight: col.implicitHeight

    // Which month is on screen, as a year/month pair (a Date would drift
    // when stepping past month lengths).
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property var today: new Date()
    readonly property bool isThisMonth: viewYear === today.getFullYear() && viewMonth === today.getMonth()

    // Monday-first offset of the 1st, and the month's length.
    readonly property int firstDow: (new Date(viewYear, viewMonth, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()

    readonly property real cellW: (width - 6 * 4) / 7
    readonly property real cellH: 32

    function step(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0) {
            m += 12;
            y -= 1;
        }
        while (m > 11) {
            m -= 12;
            y += 1;
        }
        viewMonth = m;
        viewYear = y;
    }

    // Reopening the page always returns to the current month.
    Connections {
        target: CenterNav
        function onPageChanged() {
            if (CenterNav.page === "calendar") {
                var n = new Date();
                page.viewYear = n.getFullYear();
                page.viewMonth = n.getMonth();
            }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Config.gap

        PageHeader {
            width: parent.width
            title: "Calendar"
        }

        // Month stepper.
        Item {
            width: parent.width
            height: 30

            IconButton {
                id: prev
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 28
                implicitHeight: 28
                glyph: Icons.chevronLeft
                glyphSize: 11
                onClicked: page.step(-1)
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(new Date(page.viewYear, page.viewMonth, 1), "MMMM yyyy")
                color: Theme.textPrimary
                font.family: Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 28
                implicitHeight: 28
                glyph: Icons.chevronRight
                glyphSize: 11
                onClicked: page.step(1)
            }
        }

        // Weekday initials.
        Row {
            spacing: 4
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: page.cellW
                    height: 18

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.index > 4 ? Theme.textFaint : Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // Six weeks covers every month layout.
        Grid {
            columns: 7
            spacing: 4

            Repeater {
                model: 42
                delegate: Item {
                    id: cell
                    required property int index
                    readonly property int day: index - page.firstDow + 1
                    readonly property bool valid: day >= 1 && day <= page.daysInMonth
                    readonly property bool isToday: page.isThisMonth && valid && day === page.today.getDate()
                    readonly property bool weekend: (index % 7) > 4

                    width: page.cellW
                    height: page.cellH

                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, 32)
                        height: 28
                        radius: height / 2
                        antialiasing: true
                        color: cell.isToday ? Theme.accent : "transparent"
                        visible: cell.valid

                        Text {
                            anchors.centerIn: parent
                            text: cell.day
                            color: cell.isToday ? Theme.accentText : cell.weekend ? Theme.textMuted : Theme.textSecondary
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                            font.weight: cell.isToday ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }
    }
}
