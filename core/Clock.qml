pragma Singleton

import QtQuick

// One clock for the whole shell. Minute precision is enough for everything
// that shows time; the 15 s tick keeps the rollover tight without spinning.
QtObject {
    id: clock

    property string time: ""
    property string date: ""
    property string weekday: ""

    function _tick() {
        var d = new Date();
        clock.time = Qt.formatDateTime(d, "HH:mm");
        clock.date = Qt.formatDateTime(d, "d MMMM");
        clock.weekday = Qt.formatDateTime(d, "dddd");
    }

    property Timer _t: Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: clock._tick()
    }

    Component.onCompleted: _tick()
}
