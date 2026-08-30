// Key HUD overlay: reads the latest key combination written by
// screenrecord-keys-daemon (evdev backend) and renders it as a click-through
// HUD with drag / wheel-scale / inline-edit / lock / hide, matching the
// xifan.overlay-title interaction model.

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "KeysModel.js" as KeysModel

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool editing: false
  property bool inlineEditing: false

  property string text: ""
  property int fontSize: 18
  property string fontFamily: "monospace"
  property color textColor: "#ffffff"
  property string anchorX: "right"
  property string anchorY: "bottom"
  property int marginX: 36
  property int marginY: 150
  property real timeoutMs: 2000

  // Set true when the overlay is broadcast-open and should hide on timeout.
  property bool autoHide: true
  property real lastShow: 0

  readonly property string daemonPath: Qt.resolvedUrl("daemon.py").toString().replace(/^file:\/\//, "")

  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/screenrecord/keys.conf"

  FileView {
    id: confView
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: if (!root.editing)
      root.applyConfig(text())
    onFileChanged: if (!root.editing)
      reload()
  }

  function applyConfig(raw) {
    var cfg = KeysModel.parseConfig(raw);
    root.fontSize = cfg.fontSize;
    root.fontFamily = cfg.fontFamily;
    root.textColor = cfg.textColor;
    root.anchorX = cfg.anchorX;
    root.anchorY = cfg.anchorY;
    root.marginX = cfg.marginX;
    root.marginY = cfg.marginY;
  }

  function saveConfig() {
    var cfg = {
      fontSize: root.fontSize,
      fontFamily: root.fontFamily,
      textColor: root.textColor,
      anchorX: root.anchorX,
      anchorY: root.anchorY,
      marginX: root.marginX,
      marginY: root.marginY
    };
    var serialized = KeysModel.serializeConfig(cfg);
    Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"", "--", serialized, root.configPath]);
  }

  function onKeyState(raw) {
    var t = String(raw || "").trim();
    if (t === "")
      return;
    root.text = t;
    root.lastShow = root.nowMs();
    if (root.autoHide)
      root.opened = true;
  }

  function nowMs() {
    return (typeof Date.now === "function") ? Date.now() : (new Date()).getTime();
  }

  Timer {
    interval: 250
    running: root.autoHide && root.opened
    repeat: true
    onTriggered: {
      if (root.autoHide && root.nowMs() - root.lastShow > root.timeoutMs)
        root.opened = false;
    }
  }

  Process {
    id: daemonProc
    command: ["python3", root.daemonPath]
    running: true
    stdout: SplitParser {
      onRead: function (line) {
        root.onKeyState(line);
      }
    }
    stderr: SplitParser {
      onRead: function (line) {
        console.log("screenrecord-keys-daemon:", line);
      }
    }
    // The overlay owns the daemon: if it dies (broken pipe, crash, evdev
    // hiccup) restart it so the HUD never goes silent mid-session. The timer
    // backoff keeps a crash-loop from pinning the CPU.
    onExited: function (code, status) {
      daemonRestartTimer.start();
    }
  }

  Timer {
    id: daemonRestartTimer
    interval: 500
    onTriggered: {
      daemonProc.running = false;
      daemonProc.running = true;
    }
  }

  function toggle() {
    if (root.opened) {
      root.opened = false;
      root.autoHide = false;
    } else {
      root.opened = true;
      root.autoHide = true;
      root.lastShow = root.nowMs();
    }
  }

  function lockEdit() {
    root.saveConfig();
    root.inlineEditing = false;
    root.editing = false;
  }

  function toggleEdit() {
    if (root.editing)
      root.lockEdit();
    else {
      root.opened = true;
      root.autoHide = false;
      root.editing = true;
    }
  }

  IpcHandler {
    target: "xifan.overlay-keys"

    function key(text: string): string {
      root.onKeyState(text);
      return "ok";
    }
    function toggle(): string {
      root.toggle();
      return root.opened ? "open" : "closed";
    }
    function edit(): string {
      root.toggleEdit();
      return root.editing ? "editing" : (root.opened ? "open" : "closed");
    }
    function show(): string {
      root.opened = true;
      root.autoHide = true;
      root.lastShow = root.nowMs();
      return "open";
    }
    function hide(): string {
      root.opened = false;
      root.autoHide = false;
      return "closed";
    }
    function state(): string {
      if (!root.opened)
        return "closed";
      return root.editing ? "editing" : "open";
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-screenrecord-keys"
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

      Keys.onPressed: function (event) {
        if (!root.editing)
          return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.lockEdit();
          event.accepted = true;
        } else if (event.key === Qt.Key_Escape) {
          if (root.inlineEditing)
            root.inlineEditing = false;
          else
            root.lockEdit();
          event.accepted = true;
        }
      }

      Item {
        id: card
        width: Math.min(contentRow.implicitWidth + (root.editing ? 24 : 12), parent.width - 48)
        height: contentRow.implicitHeight + (root.editing ? 16 : 0)

        x: root.anchorX === "left" ? root.marginX : root.anchorX === "right" ? parent.width - root.marginX - width : Math.round((parent.width - width) / 2)
        y: root.anchorY === "top" ? root.marginY : root.anchorY === "bottom" ? parent.height - root.marginY - height : Math.round((parent.height - height) / 2)

        // HUD backdrop in edit mode
        Rectangle {
          id: hudBorder
          visible: root.editing
          anchors.fill: parent
          radius: Style.cornerRadius
          color: Util.alpha(Color.popups.background, 0.45)
          border.color: Color.accent
          border.width: 1.5
        }

        // Drag & Wheel Scale
        MouseArea {
          id: dragArea
          visible: root.editing && !root.inlineEditing
          anchors.fill: parent
          cursorShape: Qt.SizeAllCursor
          hoverEnabled: true

          property real startGlobalX: 0
          property real startGlobalY: 0
          property int startMarginX: 0
          property int startMarginY: 0

          onPressed: function (mouse) {
            var p = dragArea.mapToItem(null, mouse.x, mouse.y);
            startGlobalX = p.x;
            startGlobalY = p.y;
            startMarginX = root.marginX;
            startMarginY = root.marginY;
          }

          onPositionChanged: function (mouse) {
            if (mouse.buttons & Qt.LeftButton) {
              var p = dragArea.mapToItem(null, mouse.x, mouse.y);
              var dx = Math.round(p.x - startGlobalX);
              var dy = Math.round(p.y - startGlobalY);
              if (root.anchorX === "right")
                root.marginX = Math.max(0, startMarginX - dx);
              else
                root.marginX = Math.max(0, startMarginX + dx);
              if (root.anchorY === "bottom")
                root.marginY = Math.max(0, startMarginY - dy);
              else
                root.marginY = Math.max(0, startMarginY + dy);
            }
          }

          onWheel: function (wheel) {
            if (wheel.angleDelta.y > 0)
              root.fontSize = Math.min(140, root.fontSize + 1);
            else if (wheel.angleDelta.y < 0)
              root.fontSize = Math.max(10, root.fontSize - 1);
          }

          onDoubleClicked: {
            root.inlineEditing = true;
            Qt.callLater(function () {
              textInput.selectAll();
              textInput.forceActiveFocus();
            });
          }
        }

        // Content Row
        Item {
          id: contentRow
          anchors.centerIn: parent
          implicitWidth: Math.max(textMetrics.tightBoundingRect.width, 40)
          implicitHeight: Math.max(textMetrics.tightBoundingRect.height, root.fontSize * 1.2)

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
            horizontalAlignment: root.anchorX === "right" ? Text.AlignRight : Text.AlignLeft
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
            horizontalAlignment: root.anchorX === "right" ? Text.AlignRight : Text.AlignLeft
            selectByMouse: true

            onTextEdited: root.text = textInput.text
            Keys.onPressed: function (event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.text = textInput.text;
                root.lockEdit();
                event.accepted = true;
              } else if (event.key === Qt.Key_Escape) {
                root.inlineEditing = false;
                event.accepted = true;
              }
            }
          }
        }
      }
    }
  }

  TextMetrics {
    id: textMetrics
    text: root.text || " "
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    font.weight: Font.Bold
  }
}
