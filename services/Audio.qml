pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../core"

// Default sink / source volume and mute, plus the list of real (non-stream)
// devices so the Audio page can switch outputs and inputs.
QtObject {
    id: audio

    readonly property var _sink: Pipewire.defaultAudioSink
    readonly property var _source: Pipewire.defaultAudioSource
    readonly property var _allNodes: Pipewire.nodes ? Pipewire.nodes.values : []

    // Real devices only — application streams are nodes too, but they are
    // not something you'd pick as a system output.
    readonly property var sinks: {
        var out = [];
        for (var i = 0; i < _allNodes.length; i++) {
            var n = _allNodes[i];
            if (n.isSink && !n.isStream && n.audio)
                out.push(n);
        }
        return out;
    }
    readonly property var sources: {
        var out = [];
        for (var i = 0; i < _allNodes.length; i++) {
            var n = _allNodes[i];
            if (!n.isSink && !n.isStream && n.audio)
                out.push(n);
        }
        return out;
    }

    // Volume reads need the node bound, so track the defaults plus anything
    // the device lists expose.
    property PwObjectTracker _tracker: PwObjectTracker {
        objects: {
            var o = [];
            if (audio._sink)
                o.push(audio._sink);
            if (audio._source)
                o.push(audio._source);
            for (var i = 0; i < audio.sinks.length; i++)
                o.push(audio.sinks[i]);
            for (var j = 0; j < audio.sources.length; j++)
                o.push(audio.sources[j]);
            return o;
        }
    }

    // Public handles on the current defaults, so pages don't reach for the
    // underscore-prefixed internals.
    readonly property var currentSink: _sink
    readonly property var currentSource: _source

    function nodeLabel(n) {
        if (!n)
            return "";
        return n.nickname || n.description || n.name || "";
    }

    // ── output ──────────────────────────────────────────────────
    readonly property bool ready: _sink && _sink.ready && _sink.audio
    readonly property real volume: ready ? _sink.audio.volume : 0
    readonly property bool muted: ready ? _sink.audio.muted : false
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property string sinkLabel: nodeLabel(_sink)

    // ── input ───────────────────────────────────────────────────
    readonly property bool micReady: _source && _source.ready && _source.audio
    readonly property real micVolume: micReady ? _source.audio.volume : 0
    readonly property bool micMuted: micReady ? _source.audio.muted : false
    readonly property int micPercent: Math.round(micVolume * 100)
    readonly property string sourceLabel: nodeLabel(_source)

    // Fired whenever the sink volume/mute changes for any reason — the notch
    // uses this as the system volume OSD.
    signal changed(bool userDriven)
    property bool _selfChange: false

    function setVolume(v) {
        if (!ready)
            return;
        _selfChange = true;
        _sink.audio.volume = Config.clamp(v, 0, 1);
    }
    function toggleMute() {
        if (!ready)
            return;
        _selfChange = true;
        _sink.audio.muted = !_sink.audio.muted;
    }

    function setMicVolume(v) {
        if (!micReady)
            return;
        _source.audio.volume = Config.clamp(v, 0, 1);
    }
    function toggleMicMute() {
        if (!micReady)
            return;
        _source.audio.muted = !_source.audio.muted;
    }

    function setSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }
    function setSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    property Connections _sinkConn: Connections {
        target: audio.ready ? audio._sink.audio : null
        function onVolumeChanged() {
            audio.changed(audio._selfChange);
            audio._selfChange = false;
        }
        function onMutedChanged() {
            audio.changed(audio._selfChange);
            audio._selfChange = false;
        }
    }
}
