// Real-time caption HUD overlay. Receives partial/final transcription from the
// screenrecord-captions-daemon via the IpcHandler `caption` method, and renders
// a click-through bottom-centered caption with a stale timeout. Edit mode lets
// you drag to move, wheel to scale, double-click to change text, Enter to lock.

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "CaptionsModel.js" as CaptionsModel

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool editing: false
  property bool inlineEditing: false

  property string text: ""
  property int fontSize: 24
  property string fontFamily: "monospace"
  property color textColor: "#ffffff"
  property string anchorY: "bottom"
  property int marginBottom: 46
  property real staleMs: 4000
  property real lastUpdate: 0

  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
                                        + "/screenrecord/captions.conf"
  readonly property string daemonPath: (Quickshell.env("HOME") || "") + "/.local/bin/screenrecord-captions-daemon"

  FileView {
    id: confView
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: if (!root.editing) root.applyConfig(text())
    onFileChanged: if (!root.editing) reload()
  }

  function applyConfig(raw) {
    var cfg = CaptionsModel.parseConfig(raw)
    root.fontSize = cfg.fontSize
    root.fontFamily = cfg.fontFamily
    root.textColor = cfg.textColor
    root.anchorY = cfg.anchorY
    root.marginBottom = cfg.marginBottom
  }

  function saveConfig() {
    var cfg = {
      fontSize: root.fontSize,
      fontFamily: root.fontFamily,
      textColor: root.textColor,
      anchorY: root.anchorY,
      marginBottom: root.marginBottom
    }
    var serialized = CaptionsModel.serializeConfig(cfg)
    Quickshell.execDetached([
      "bash", "-c",
      "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"",
      "--",
      serialized,
      root.configPath
    ])
  }

  function nowMs() {
    return (typeof Date.now === "function") ? Date.now() : (new Date()).getTime()
  }

  function sanitizeCaption(t) {
    return String(t || "").replace(/[\r\n]+/g, "")
  }

  function startDaemon() {
    Quickshell.execDetached([root.daemonPath])
  }

  function toggle() {
    if (root.opened) {
      root.opened = false
    } else {
      root.opened = true
      root.lastUpdate = nowMs()
    }
  }

  function lockEdit() {
    root.saveConfig()
    root.inlineEditing = false
    root.editing = false
  }

  function toggleEdit() {
    if (root.editing) root.lockEdit()
    else {
      root.opened = true
      root.editing = true
    }
  }

  Component.onCompleted: root.startDaemon()

  IpcHandler {
    target: "xifan.overlay-captions"

    function caption(text: string, kind: string): string {
      var t = root.sanitizeCaption(text)
      if (kind === "clear" || t === "") {
        root.text = ""
        root.opened = false
        return "ok"
      }
      root.text = t
      root.lastUpdate = nowMs()
      root.opened = true
      return "ok"
    }
    function toggle(): string {
      root.toggle()
      return root.opened ? "open" : "closed"
    }
    function edit(): string {
      root.toggleEdit()
      return root.editing ? "editing" : (root.opened ? "open" : "closed")
    }
    function show(): string {
      root.opened = true
      root.lastUpdate = nowMs()
      return "open"
    }
    function hide(): string {
      root.opened = false
      root.text = ""
      return "closed"
    }
    function state(): string {
      if (!root.opened) return "closed"
      return root.editing ? "editing" : "open"
    }
  }

  // Hide the caption if it has not been updated recently (no speech).
  Timer {
    id: staleTimer
    interval: 500
    running: root.opened && !root.editing
    repeat: true
    onTriggered: {
      if (root.opened && !root.editing && nowMs() - root.lastUpdate > root.staleMs)
        root.opened = false
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-screenrecord-captions"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    mask: Region {
      item: root.editing ? card : null
    }

    Item {
      id: hudContainer
      anchors.fill: parent
      focus: root.editing

      Keys.onPressed: function(event) {
        if (!root.editing) return
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.lockEdit()
          event.accepted = true
        } else if (event.key === Qt.Key_Escape) {
          if (root.inlineEditing) root.inlineEditing = false
          else root.lockEdit()
          event.accepted = true
        }
      }

      Item {
        id: card
        // Full-bleed like the title overlay max width: nearly screen-wide so
        // captions stay on one line instead of wrapping in a shrink-wrapped box.
        width: parent.width - 48
        height: contentRow.implicitHeight + (root.editing ? 16 : 0)

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.anchorY === "bottom" ? parent.height - root.marginBottom - height
            : root.anchorY === "top" ? root.marginBottom
            : Math.round((parent.height - height) / 2)

        Rectangle {
          id: hudBorder
          visible: root.editing
          anchors.fill: parent
          radius: Style.cornerRadius
          color: Util.alpha(Color.popups.background, 0.45)
          border.color: Color.accent
          border.width: 1.5
        }

        MouseArea {
          id: dragArea
          visible: root.editing && !root.inlineEditing
          anchors.fill: parent
          cursorShape: Qt.SizeAllCursor
          hoverEnabled: true

          property real startGlobalX: 0
          property real startGlobalY: 0
          property int startMarginBottom: 0

          onPressed: function(mouse) {
            startGlobalY = dragArea.mapToItem(null, mouse.x, mouse.y).y
            startMarginBottom = root.marginBottom
          }

          onPositionChanged: function(mouse) {
            if (mouse.buttons & Qt.LeftButton) {
              var y = dragArea.mapToItem(null, mouse.x, mouse.y).y
              var dy = Math.round(y - startGlobalY)
              if (root.anchorY === "bottom") root.marginBottom = Math.max(0, startMarginBottom - dy)
              else root.marginBottom = Math.max(0, startMarginBottom + dy)
            }
          }

          onWheel: function(wheel) {
            if (wheel.angleDelta.y > 0) root.fontSize = Math.min(140, root.fontSize + 2)
            else if (wheel.angleDelta.y < 0) root.fontSize = Math.max(12, root.fontSize - 2)
          }

          onDoubleClicked: {
            root.inlineEditing = true
            Qt.callLater(function() {
              textInput.selectAll()
              textInput.forceActiveFocus()
            })
          }
        }

        Item {
          id: contentRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: root.editing ? 12 : 0
          anchors.rightMargin: root.editing ? 12 : 0
          implicitHeight: Math.max(root.fontSize * 1.2, 24)
          height: implicitHeight

          Text {
            id: displayText
            visible: !root.inlineEditing
            anchors.fill: parent
            text: root.text
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: Font.Bold
            style: Text.Outline
            styleColor: Util.alpha(Qt.rgba(0, 0, 0, 1), 0.95)
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.NoWrap
            maximumLineCount: 1
            elide: Text.ElideNone
          }

          TextInput {
            id: textInput
            visible: root.editing && root.inlineEditing
            anchors.fill: parent
            text: root.text
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: Font.Bold
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: TextInput.NoWrap
            clip: true
            selectByMouse: true

            onTextEdited: root.text = textInput.text
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.text = textInput.text
                root.lockEdit()
                event.accepted = true
              } else if (event.key === Qt.Key_Escape) {
                root.inlineEditing = false
                event.accepted = true
              }
            }
          }
        }
      }
    }
  }
}
