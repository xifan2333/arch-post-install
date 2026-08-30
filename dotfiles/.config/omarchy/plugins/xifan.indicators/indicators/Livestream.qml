import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property bool streaming: false

  active: streaming
  activeText: "󰻒"
  inactiveText: "󰻒"
  activeTooltipText: "Stop livestream"
  inactiveTooltipText: "Livestream"

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
    command: ["livestream", "is-active"]
    onExited: function (exitCode) {
      root.streaming = exitCode === 0;
    }
  }

  onPressed: function () {
    if (root.bar) {
      root.bar.run(root.streaming ? "livestream stop" : "omarchy-menu toggle trigger.capture.livestream");
    }
  }
}
