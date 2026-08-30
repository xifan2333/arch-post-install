pragma ComponentBehavior: Bound

// Livestream configuration dialog overlay. Allows configuring multi-platform RTMP
// targets, stream keys, video/audio bitrates, and aspect ratios (16:9 vs 9:16).
// Reads and writes ~/.config/livestream/config.json directly with auto-save on interaction.

import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "LivestreamConfigModel.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property int videoBitrate: 6000
  property int audioBitrate: 160
  property var platforms: []

  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
                                        + "/livestream/config.json"

  FileView {
    id: confView
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: if (!root.opened) root.loadConfig(text())
    onFileChanged: if (!root.opened) reload()
  }

  function loadConfig(raw) {
    const cfg = Model.parseConfig(raw)
    root.videoBitrate = cfg.videoBitrate
    root.audioBitrate = cfg.audioBitrate
    root.platforms = cfg.platforms.map(function(p) {
      return {
        enabled: p.enabled,
        name: p.name,
        server: p.server,
        key: p.key,
        aspect_ratio: p.aspect_ratio,
        showKey: false
      }
    })
  }

  function saveConfig() {
    const payload = {
      videoBitrate: root.videoBitrate,
      audioBitrate: root.audioBitrate,
      platforms: root.platforms
    }
    const serialized = Model.serializeConfig(payload)
    Quickshell.execDetached([
      "bash", "-c",
      "mkdir -p \"$(dirname \"$2\")\" && chmod 700 \"$(dirname \"$2\")\" 2>/dev/null && printf '%s' \"$1\" > \"$2\" && chmod 600 \"$2\"",
      "--",
      serialized,
      root.configPath
    ])
  }

  function scheduleSave() {
    saveTimer.restart()
  }

  Timer {
    id: saveTimer
    interval: 250
    repeat: false
    onTriggered: root.saveConfig()
  }

  function open() {
    confView.reload()
    root.opened = true
  }

  function close() {
    root.opened = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function addPlatform() {
    const copy = root.platforms.slice()
    copy.push(Model.createEmptyPlatform())
    root.platforms = copy
    root.scheduleSave()
  }

  function removePlatform(index) {
    if (index < 0 || index >= root.platforms.length) return
    const copy = root.platforms.slice()
    copy.splice(index, 1)
    root.platforms = copy
    root.scheduleSave()
  }

  function updatePlatform(index, field, value) {
    if (index < 0 || index >= root.platforms.length) return
    const copy = root.platforms.slice()
    copy[index][field] = value
    root.platforms = copy
    if (field !== "showKey") root.scheduleSave()
  }

  IpcHandler {
    target: "xifan.livestream-config"

    function toggle(): string {
      root.toggle()
      return root.opened ? "open" : "closed"
    }
    function show(): string {
      root.open()
      return "open"
    }
    function hide(): string {
      root.close()
      return "closed"
    }
    function state(): string {
      return root.opened ? "open" : "closed"
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-livestream-config"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Item {
      id: keyScope
      anchors.fill: parent
      focus: root.opened
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          root.close()
          event.accepted = true
        }
      }

      Rectangle {
        id: scrim
        anchors.fill: parent
        color: Util.alpha(Color.background, 0.75)

      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }

      Rectangle {
        id: card
        width: Math.min(parent.width - 48, 920)
        height: Math.min(parent.height - 48, 540)
        anchors.centerIn: parent
        color: Color.popups.background
        border.color: Color.popups.border
        border.width: Style.normalBorderWidth
        radius: Style.cornerRadius
        clip: true

        MouseArea {
          anchors.fill: parent
          onClicked: {} // Intercept clicks inside card
        }

        Column {
          anchors.fill: parent
          anchors.margins: 20
          spacing: 14

          // Header Row
          Row {
            width: parent.width

            Text {
              text: "󰕧  直播推流配置"
              color: Color.foreground
              font.family: Style.font.family
              font.pixelSize: Style.font.title
              font.weight: Font.Bold
            }
          }

          // Bitrate Settings Bar
          Rectangle {
            width: parent.width
            height: 48
            color: Util.alpha(Color.foreground, 0.04)
            radius: Style.cornerRadius
            border.color: Util.alpha(Color.foreground, 0.08)
            border.width: 1

            Row {
              anchors.centerIn: parent
              spacing: 24

              Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                Text {
                  text: "视频码率 (kbps):"
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                  width: 100
                  text: String(root.videoBitrate)
                  validator: IntValidator { bottom: 100; top: 50000 }
                  onTextEdited: {
                    root.videoBitrate = Number(text) || 6000
                    root.scheduleSave()
                  }
                }
              }

              Row {
                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                Text {
                  text: "音频码率 (kbps):"
                  color: Color.foreground
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }
                TextField {
                  width: 80
                  text: String(root.audioBitrate)
                  validator: IntValidator { bottom: 32; top: 320 }
                  onTextEdited: {
                    root.audioBitrate = Number(text) || 160
                    root.scheduleSave()
                  }
                }
              }
            }
          }

          // Platforms Header & Add Button
          Row {
            width: parent.width
            spacing: 12

            Text {
              text: "推流平台列表"
              color: Color.accent
              font.family: Style.font.family
              font.pixelSize: Style.font.body
              font.weight: Font.Bold
              anchors.verticalCenter: parent.verticalCenter
            }

            Item {
              width: parent.width - 240
              height: 1
            }

            Button {
              text: "+ 添加平台"
              bordered: true
              accent: Color.accent
              onClicked: root.addPlatform()
            }
          }

          // Platform List View
          Rectangle {
            width: parent.width
            height: parent.height - 130
            color: "transparent"

            Text {
              visible: root.platforms.length === 0
              anchors.centerIn: parent
              text: "暂无配置的推流平台，点击上方「+ 添加平台」添加"
              color: Qt.darker(Color.foreground, 1.6)
              font.family: Style.font.family
              font.pixelSize: Style.font.body
            }

            QQC.ScrollView {
              anchors.fill: parent
              clip: true

              ListView {
                id: platformList
                width: parent.width
                model: root.platforms
                spacing: 8

                delegate: Rectangle {
                  id: rowCard
                  required property var modelData
                  required property int index
                  width: parent ? parent.width - 8 : 800
                  height: 52
                  color: Util.alpha(Color.foreground, rowCard.modelData.enabled ? 0.05 : 0.02)
                  radius: Style.cornerRadius
                  border.color: Util.alpha(Color.foreground, rowCard.modelData.enabled ? 0.12 : 0.05)
                  border.width: 1

                  Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter

                    ToggleSwitch {
                      checked: rowCard.modelData.enabled
                      anchors.verticalCenter: parent.verticalCenter
                      onToggled: root.updatePlatform(rowCard.index, "enabled", !rowCard.modelData.enabled)
                    }

                    TextField {
                      width: 100
                      placeholderText: "平台 (如 bilibili)"
                      text: rowCard.modelData.name
                      anchors.verticalCenter: parent.verticalCenter
                      onTextEdited: {
                        rowCard.modelData.name = text
                        root.scheduleSave()
                      }
                    }

                    TextField {
                      width: rowCard.width - 450
                      placeholderText: "RTMP 服务器地址"
                      text: rowCard.modelData.server
                      anchors.verticalCenter: parent.verticalCenter
                      onTextEdited: {
                        rowCard.modelData.server = text
                        root.scheduleSave()
                      }
                    }

                    TextField {
                      width: 130
                      placeholderText: "推流码"
                      text: rowCard.modelData.key
                      password: !rowCard.modelData.showKey
                      anchors.verticalCenter: parent.verticalCenter
                      onTextEdited: {
                        rowCard.modelData.key = text
                        root.scheduleSave()
                      }
                    }

                    // 1. 比例 (16:9 / 9:16)
                    Button {
                      text: rowCard.modelData.aspect_ratio || "16:9"
                      anchors.verticalCenter: parent.verticalCenter
                      bordered: true
                      horizontalPadding: 8
                      onClicked: {
                        const next = (rowCard.modelData.aspect_ratio === "9:16") ? "16:9" : "9:16"
                        root.updatePlatform(rowCard.index, "aspect_ratio", next)
                      }
                    }

                    // 2. 可见性 (显示/隐藏推流码)
                    Button {
                      text: rowCard.modelData.showKey ? "󰈈" : "󰈉"
                      anchors.verticalCenter: parent.verticalCenter
                      fontSize: Style.font.title
                      horizontalPadding: 6
                      onClicked: root.updatePlatform(rowCard.index, "showKey", !rowCard.modelData.showKey)
                    }

                    // 3. 删除
                    Button {
                      text: "󰆴"
                      anchors.verticalCenter: parent.verticalCenter
                      fontSize: Style.font.title
                      horizontalPadding: 8
                      foreground: Color.urgent
                      onClicked: root.removePlatform(rowCard.index)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  }
}
