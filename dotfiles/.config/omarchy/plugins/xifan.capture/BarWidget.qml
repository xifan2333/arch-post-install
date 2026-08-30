import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "xifan.capture"

  property string screenState: "idle"
  property var indicatorHost: null

  function applyState(raw) {
    var value = String(raw || "").trim();
    root.screenState = (value === "recording" || value === "livestream") ? value : "idle";
  }

  function bindIndicatorHost() {
    var widgets = root.bar && typeof root.bar.moduleWidgets === "function" ? root.bar.moduleWidgets("omarchy.indicators") : [];
    root.indicatorHost = widgets.length > 0 ? widgets[0] : null;
  }

  function refresh() {
    if (!statusProc.running)
      statusProc.running = true;
  }

  visible: root.screenState !== "idle"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: {
    root.bindIndicatorHost();
    root.refresh();
  }
  Component.onCompleted: root.refresh()

  Connections {
    target: root.bar
    ignoreUnknownSignals: true
    function onModuleSlotsChanged() {
      root.bindIndicatorHost();
    }
  }

  // Same contract as Omarchy's stock ScreenRecording indicator: the host
  // broadcasts refresh, this widget does one status read.
  Connections {
    target: root.indicatorHost
    ignoreUnknownSignals: true
    function onRefreshRequested() {
      root.refresh();
    }
  }

  Process {
    id: statusProc
    command: ["capture-router", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyState(text)
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
    tooltipText: root.screenState === "livestream" ? "Livestream… click to stop" : "Recording… click to stop"

    onPressed: function (b) {
      if (!root.bar)
        return;
      if (b === Qt.RightButton)
        root.bar.run("capture-router menu");
      else
        root.bar.run("capture-router toggle-active");
    }
  }
}
