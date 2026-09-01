import QtQuick
import Quickshell.Io
import qs.Ui

BarIndicator {
  id: root

  property bool isMax: false
  property string currentSpeed: "0"

  active: isMax
  activeText: "󰈐"
  inactiveText: "󰖝"
  activeTooltipText: "ThinkPad Fan: MAX (" + currentSpeed + " RPM) - Click for Auto"
  inactiveTooltipText: "ThinkPad Fan: Auto (" + currentSpeed + " RPM) - Click to Boost"

  function refresh() {
    if (!root.bar || statusProc.running)
      return;
    statusProc.running = true;
  }

  onBarChanged: refresh()
  Component.onCompleted: refresh()

  Timer {
    interval: 4000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() {
      root.refresh();
    }
  }

  Process {
    id: statusProc
    command: ["bash", "-c", "echo $(thinkpad-fan is-max && echo 1 || echo 0):$(thinkpad-fan speed)"]
    stdout: SplitParser {
      onRead: function (data) {
        var parts = String(data || "").trim().split(":");
        if (parts.length >= 2) {
          root.isMax = parts[0] === "1";
          root.currentSpeed = parts[1];
        }
      }
    }
  }

  onPressed: function () {
    if (root.bar) {
      root.bar.run("thinkpad-fan toggle");
      root.isMax = !root.isMax;
      refreshTimer.restart();
    }
  }

  Timer {
    id: refreshTimer
    interval: 800
    onTriggered: root.refresh()
  }
}
