import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "xifan.thinkpad-fan"
  ipcTarget: "xifan.thinkpad-fan"
  manageIpc: false

  property string fanSpeed: "0"
  property string fanLevel: "auto"
  property string cpuTemp: "—"
  property bool isMax: fanLevel === "disengaged" || fanLevel === "64" || fanLevel === "full-speed"

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
          root.fanLevel = parts[1] || "auto";
          if (parts.length >= 3 && parts[2])
            root.cpuTemp = parts[2];
        }
      }
    }
  }

  function setFanLevel(lvl) {
    if (root.bar) {
      root.bar.run("thinkpad-fan " + lvl);
      root.fanLevel = lvl;
      refreshTimer.restart();
    }
  }

  Timer {
    id: refreshTimer
    interval: 600
    onTriggered: root.refresh()
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
    function setLevel(lvl: string): string {
      root.setFanLevel(lvl);
      return "ok";
    }
    function status(): string {
      return root.fanSpeed + " RPM (" + root.fanLevel + ")";
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.isMax ? "󰈐" : "󰖝"
    tooltipText: "Fan: " + (root.isMax ? "MAX" : root.fanLevel) + " (" + root.fanSpeed + " RPM)"
    onPressed: function (b) {
      if (b === Qt.RightButton) {
        root.setFanLevel(root.isMax ? "auto" : "max");
      } else {
        root.toggle();
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(340))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(14)

      Item {
        width: parent.width
        implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroRpm.implicitHeight)

        Text {
          id: heroIcon
          textFormat: Text.PlainText
          text: root.isMax ? "󰈐" : "󰖝"
          color: root.isMax ? Style.color.urgent : root.foreground
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
            text: (root.isMax ? "Turbo Blower" : (root.fanLevel === "auto" ? "BIOS Smart Curve" : ("Fixed Level " + root.fanLevel))) + " · CPU " + root.cpuTemp
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
          color: root.isMax ? Style.color.urgent : root.foreground
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

      Column {
        width: parent.width
        spacing: Style.space(10)

        PanelSectionHeader {
          text: "FAN PROFILE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Row {
          id: profileRow
          width: parent.width
          spacing: Style.space(6)

          readonly property real cellWidth: (width - spacing * 2) / 3

          Button {
            width: profileRow.cellWidth
            text: "Auto"
            fontSize: Style.font.bodySmall
            foreground: root.foreground
            fontFamily: root.fontFamily
            active: root.fanLevel === "auto"
            onClicked: root.setFanLevel("auto")
          }

          Button {
            width: profileRow.cellWidth
            text: "Level 4"
            fontSize: Style.font.bodySmall
            foreground: root.foreground
            fontFamily: root.fontFamily
            active: root.fanLevel === "4"
            onClicked: root.setFanLevel("4")
          }

          Button {
            width: profileRow.cellWidth
            text: "MAX Boost"
            fontSize: Style.font.bodySmall
            foreground: root.foreground
            fontFamily: root.fontFamily
            active: root.isMax
            onClicked: root.setFanLevel("max")
          }
        }
      }

      Column {
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader {
          text: "MANUAL LEVEL"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Row {
          id: levelGrid
          width: parent.width
          spacing: Style.space(4)

          readonly property var levels: ["0", "1", "2", "3", "4", "5", "6", "7"]
          readonly property real cellWidth: (width - spacing * (levels.length - 1)) / levels.length

          Repeater {
            model: levelGrid.levels

            Button {
              required property var modelData
              width: levelGrid.cellWidth
              text: String(modelData)
              fontSize: Style.font.caption
              foreground: root.foreground
              fontFamily: root.fontFamily
              active: root.fanLevel === String(modelData)
              onClicked: root.setFanLevel(String(modelData))
            }
          }
        }
      }
    }
  }
}
