import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "xifan.intel-gpu"
  ipcTarget: "xifan.intel-gpu"
  manageIpc: false

  property string gpuCurFreq: "650"
  property string gpuLevel: "auto"
  property string lastManualLevel: "max"
  property real wheelAccumulator: 0

  readonly property bool isAuto: gpuLevel === "auto"
  readonly property int sliderValue: Model.levelToIndex(gpuLevel)
  readonly property string iconText: Model.gpuIcon(gpuLevel)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (statusProc.running)
      return;
    statusProc.running = true;
  }

  Component.onCompleted: refresh()

  Timer {
    interval: 3000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["bash", "-c", "echo $(intel-gpu-freq cur):$(intel-gpu-freq level)"]
    stdout: SplitParser {
      onRead: function (data) {
        var parts = String(data || "").trim().split(":");
        if (parts.length >= 2) {
          root.gpuCurFreq = parts[0] || "650";
          var lvl = parts[1] || "auto";
          root.gpuLevel = lvl;
          if (lvl !== "auto") {
            root.lastManualLevel = lvl;
          }
        }
      }
    }
  }

  function showGpuOsd(lvl) {
    if (root.opened)
      return;
    if (!bar || !bar.shell)
      return;
    var targetLvl = String(lvl || root.gpuLevel);
    var idx = Model.levelToIndex(targetLvl);
    var osdText = Model.levelOsdText(targetLvl);
    var iconGlyph = Model.gpuIcon(targetLvl);

    bar.shell.summon("omarchy.osd", JSON.stringify({
      icon: iconGlyph,
      value: idx,
      max: 8,
      progressText: osdText
    }));
  }

  function setGpuLevel(lvl, fromUserAction) {
    var targetLvl = String(lvl || "auto");
    if (targetLvl !== "auto") {
      root.lastManualLevel = targetLvl;
    }
    root.gpuLevel = targetLvl;
    if (root.bar) {
      root.bar.run("intel-gpu-freq " + targetLvl);
      refreshTimer.restart();
    }
    if (fromUserAction) {
      root.showGpuOsd(targetLvl);
    }
  }

  function toggleAutoManual(fromUserAction) {
    if (root.isAuto) {
      root.setGpuLevel(root.lastManualLevel || "max", fromUserAction);
    } else {
      root.setGpuLevel("auto", fromUserAction);
    }
  }

  function stepGpu(deltaSteps) {
    var nextLvl = Model.stepLevel(root.gpuLevel, deltaSteps);
    root.setGpuLevel(nextLvl, true);
  }

  Timer {
    id: refreshTimer
    interval: 600
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconText
    onPressed: function (b) {
      if (b === Qt.RightButton) {
        root.toggleAutoManual(true);
      } else {
        root.toggle();
      }
    }

    onWheelMoved: function (delta) {
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta);
      root.wheelAccumulator = wheel.remainder;
      if (wheel.steps === 0)
        return;
      root.stepGpu(wheel.steps);
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void {
      root.open();
    }
    function close(): void {
      root.close();
    }
    function toggle(): void {
      root.toggle();
    }
    function toggleAuto(): string {
      root.toggleAutoManual(true);
      return root.gpuLevel;
    }
    function setLevel(lvl: string): string {
      root.setGpuLevel(lvl, true);
      return "ok";
    }
    function status(): string {
      return root.gpuCurFreq + " MHz (" + root.gpuLevel + ")";
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (dx !== 0)
          root.stepGpu(dx > 0 ? 1 : -1);
        else if (dy !== 0)
          root.stepGpu(dy > 0 ? 1 : -1);
      }
      onActivateRequested: root.toggleAutoManual(true)
      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        root.switchPanel(direction);
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // Hero Header
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroMhz.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.iconText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroMhz.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Intel HD Graphics"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: Model.levelDisplayName(root.gpuLevel) + " · GT2"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroMhz
            text: root.gpuCurFreq + " MHz"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        // Single Minimalist GPU Frequency Slider
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSlider {
            id: gpuSlider
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: 8
            step: 1
            value: root.sliderValue
            opacity: root.isAuto ? 0.6 : 1.0

            onMoved: function (v) {
              var newLvl = Model.indexToLevel(v);
              root.setGpuLevel(newLvl, true);
            }
            onRightClicked: {
              root.toggleAutoManual(true);
            }
          }

          Item {
            width: parent.width
            implicitHeight: Math.max(autoLabel.implicitHeight, maxLabel.implicitHeight)

            Text {
              id: autoLabel
              text: "Auto"
              color: root.isAuto ? root.foreground : Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.isAuto
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: midLabel
              text: "950 MHz"
              color: root.sliderValue === 4 ? root.foreground : Qt.darker(root.foreground, 1.8)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.sliderValue === 4
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: maxLabel
              text: "MAX Boost"
              color: root.sliderValue === 8 ? root.foreground : Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.sliderValue === 8
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
