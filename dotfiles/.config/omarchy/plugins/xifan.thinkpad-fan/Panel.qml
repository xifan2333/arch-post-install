import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "xifan.thinkpad-fan"
  ipcTarget: "xifan.thinkpad-fan"
  manageIpc: false

  property string fanSpeed: "0"
  property string fanLevel: "auto"
  property string lastManualLevel: "max"
  property string cpuTemp: "—"
  property real wheelAccumulator: 0

  readonly property bool isAuto: fanLevel === "auto"
  readonly property bool isMaxLevel: Model.isMax(fanLevel)
  readonly property int sliderValue: Model.levelToIndex(fanLevel)

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
    command: ["bash", "-c", "echo $(thinkpad-fan speed):$(thinkpad-fan level):$(sensors 2>/dev/null | grep -m1 'Package id' | awk '{print $4}' | tr -d '+')"]
    stdout: SplitParser {
      onRead: function (data) {
        var parts = String(data || "").trim().split(":");
        if (parts.length >= 2) {
          root.fanSpeed = parts[0] || "0";
          var lvl = parts[1] || "auto";
          root.fanLevel = lvl;
          if (lvl !== "auto") {
            root.lastManualLevel = lvl;
          }
          if (parts.length >= 3 && parts[2])
            root.cpuTemp = parts[2];
        }
      }
    }
  }

  function setFanLevel(lvl) {
    var targetLvl = String(lvl || "auto");
    if (targetLvl !== "auto") {
      root.lastManualLevel = targetLvl;
    }
    root.fanLevel = targetLvl;
    if (root.bar) {
      root.bar.run("thinkpad-fan " + targetLvl);
      refreshTimer.restart();
    }
  }

  function toggleAutoManual() {
    if (root.isAuto) {
      root.setFanLevel(root.lastManualLevel || "max");
    } else {
      root.setFanLevel("auto");
    }
  }

  function stepFan(deltaSteps) {
    var nextLvl = Model.stepLevel(root.fanLevel, deltaSteps);
    root.setFanLevel(nextLvl);
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
    text: root.isMaxLevel ? "󰈐" : "󰖝"
    tooltipText: "Fan: " + (root.isAuto ? "Auto" : (root.isMaxLevel ? "MAX" : "Level " + root.fanLevel)) + " (" + root.fanSpeed + " RPM) · CPU " + root.cpuTemp
    onPressed: function (b) {
      if (b === Qt.RightButton) {
        root.toggleAutoManual();
      } else {
        root.toggle();
      }
    }

    onWheelMoved: function (delta) {
      var wheel = Util.wheelSteps(root.wheelAccumulator, delta);
      root.wheelAccumulator = wheel.remainder;
      if (wheel.steps === 0)
        return;
      root.stepFan(wheel.steps);
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
      root.toggleAutoManual();
      return root.fanLevel;
    }
    function setLevel(lvl: string): string {
      root.setFanLevel(lvl);
      return "ok";
    }
    function status(): string {
      return root.fanSpeed + " RPM (" + root.fanLevel + ")";
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
          root.stepFan(dx > 0 ? 1 : -1);
        else if (dy !== 0)
          root.stepFan(dy > 0 ? 1 : -1);
      }
      onActivateRequested: root.toggleAutoManual()
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
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroRpm.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.isMaxLevel ? "󰈐" : "󰖝"
            color: root.isMaxLevel ? Style.color.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroRpm.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "ThinkPad Fan"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: Model.levelDisplayName(root.fanLevel) + " · CPU " + root.cpuTemp
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroRpm
            text: root.fanSpeed + " RPM"
            color: root.isMaxLevel ? Style.color.urgent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.headline
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        // Single Minimalist Fan Speed Slider
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSlider {
            id: fanSlider
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: 8
            step: 1
            value: root.sliderValue
            opacity: root.isAuto ? 0.6 : 1.0

            onMoved: function (v) {
              var newLvl = Model.indexToLevel(v);
              root.setFanLevel(newLvl);
            }
            onRightClicked: {
              root.setFanLevel("auto");
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
              text: "Level 4"
              color: root.fanLevel === "4" ? root.foreground : Qt.darker(root.foreground, 1.8)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.fanLevel === "4"
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: maxLabel
              text: "MAX Boost"
              color: root.isMaxLevel ? Style.color.urgent : Qt.darker(root.foreground, 1.6)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: root.isMaxLevel
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }
  }
}
