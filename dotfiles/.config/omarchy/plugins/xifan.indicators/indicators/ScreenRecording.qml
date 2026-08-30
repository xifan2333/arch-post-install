import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property bool recording: false

  active: recording
  activeText: "󰻂"
  inactiveText: "󰻂"
  activeTooltipText: "Stop recording"
  inactiveTooltipText: "Screen Recording"

  function refresh() {
    if (!root.bar || statusProc.running)
      return;
    statusProc.running = true;
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() {
      root.refresh();
    }
  }

  Process {
    id: statusProc
    command: ["bash", "-c", "livestream is-active >/dev/null 2>&1 && exit 1; exec pgrep --quiet -f '^gpu-screen-recorder'"]
    onExited: function (exitCode) {
      root.recording = exitCode === 0;
    }
  }

  onPressed: function () {
    if (root.bar) {
      root.bar.run(root.recording ? "omarchy-capture-screenrecording --stop-recording" : "omarchy-menu toggle trigger.capture.screenrecord");
    }
  }
}
