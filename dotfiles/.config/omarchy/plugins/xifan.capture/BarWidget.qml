import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xifan.capture"

  property string screenState: "idle"

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function applyState(raw) {
    var s = String(raw || "").trim()
    root.screenState = (s === "" || s === "idle") ? "idle" : s
  }

  visible: root.screenState !== "idle"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: ["capture-router", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
    }
  }

  Component.onCompleted: root.refresh()

  IpcHandler {
    target: "xifan.capture"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    slotSize: Style.bar.statusSlot
    active: true
    useActiveColor: true
    text: root.screenState === "livestream" ? "\uf144" : "\uf111"
    tooltipText: root.screenState === "livestream" ? "Livestream… click to stop"
               : "Recording… click to stop"

    onPressed: function(b) {
      if (!root.bar) return
      if (b === Qt.RightButton) root.bar.run("capture-router menu")
      else root.bar.run("capture-router toggle-active")
    }
  }
}
