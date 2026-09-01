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
  readonly property string iconText: Model.fanIcon(fanLevel)

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

  function showFanOsd(lvl) {
    if (!bar || !bar.shell)
      return;
    var targetLvl = String(lvl || root.fanLevel);
    var idx = Model.levelToIndex(targetLvl);
    var osdText = Model.levelOsdText(targetLvl);
    var iconGlyph = Model.fanIcon(targetLvl);

    bar.shell.summon("omarchy.osd", JSON.stringify({
      icon: iconGlyph,
      value: idx,
      max: 8,
      progressText: osdText
    }));
  }

  function setFanLevel(lvl, fromUserAction) {
    var targetLvl = String(lvl || "auto");
    if (targetLvl !== "auto") {
      root.lastManualLevel = targetLvl;
    }
    root.fanLevel = targetLvl;
    if (root.bar) {
      root.bar.run("thinkpad-fan " + targetLvl);
      refreshTimer.restart();
    }
    if (fromUserAction) {
      root.showFanOsd(targetLvl);
    }
  }

  function toggleAutoManual(fromUserAction) {
    if (root.isAuto) {
      root.setFanLevel(root.lastManualLevel || "max", fromUserAction);
    } else {
      root.setFanLevel("auto", fromUserAction);
    }
  }

  function stepFan(deltaSteps) {
    var nextLvl = Model.stepLevel(root.fanLevel, deltaSteps);
    root.setFanLevel(nextLvl, true);
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
    tooltipText: "Fan: " + (root.isAuto ? "Auto" : (root.isMaxLevel ? "MAX" : "Level " + root.fanLevel)) + " (" + root.fanSpeed + " RPM) · CPU " + root.cpuTemp
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
      root.toggleAutoManual(true);
      return root.fanLevel;
    }
    function setLevel(lvl: string): string {
      root.setFanLevel(lvl, true);
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
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(sliderRow.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (dx !== 0)
          root.stepFan(dx > 0 ? 1 : -1);
        else if (dy !== 0)
          root.stepFan(dy > 0 ? 1 : -1);
      }
      onActivateRequested: root.toggleAutoManual(true)
      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        root.switchPanel(direction);
      }

      Item {
        id: sliderRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: Math.max(iconItem.implicitHeight, fanSlider.implicitHeight)

        Item {
          id: iconItem
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: iconText.implicitWidth + Style.space(8)
          height: iconText.implicitHeight + Style.space(8)

          Text {
            id: iconText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: root.iconText
            color: root.isMaxLevel ? (root.bar ? root.bar.urgent : Color.urgent) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: function (mouse) {
              root.toggleAutoManual(true);
            }
          }
        }

        PanelSlider {
          id: fanSlider
          bar: root.bar
          anchors.left: iconItem.right
          anchors.leftMargin: Style.space(8)
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          minimum: 0
          maximum: 8
          step: 1
          integer: true
          value: root.sliderValue
          opacity: root.isAuto ? 0.6 : 1.0

          onMoved: function (v) {
            var newLvl = Model.indexToLevel(v);
            root.setFanLevel(newLvl, true);
          }
          onRightClicked: {
            root.toggleAutoManual(true);
          }
        }
      }
    }
  }
}
