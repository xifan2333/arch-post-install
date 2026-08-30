import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "TitleModel.js" as TitleModel

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool editing: false
  property bool inlineEditing: false

  property string text: "直播标题"
  property string fontFamily: "sans-serif"
  property int fontSize: 36
  property int fontWeight: 700
  property color textColor: "#ffffff"
  property string backgroundSpec: "rgba(0, 0, 0, 0.55)"
  property string anchorX: "left"
  property string anchorY: "top"
  property int marginX: 24
  property int marginY: 24

  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
                                        + "/screenrecord/title.conf"

  FileView {
    id: confView
    path: root.configPath
    watchChanges: true
    printErrors: false
    onLoaded: if (!root.editing) root.applyConfig(text())
    onFileChanged: if (!root.editing) reload()
  }

  function applyConfig(raw) {
    var cfg = TitleModel.parseConfig(raw)
    root.text = cfg.text
    root.fontFamily = cfg.fontFamily
    root.fontSize = cfg.fontSize
    root.fontWeight = cfg.fontWeight
    root.textColor = cfg.textColor
    root.backgroundSpec = cfg.background
    root.anchorX = cfg.anchorX
    root.anchorY = cfg.anchorY
    root.marginX = cfg.marginX
    root.marginY = cfg.marginY
  }

  function saveConfig() {
    var cfg = {
      text: root.text,
      fontFamily: root.fontFamily,
      fontSize: root.fontSize,
      fontWeight: root.fontWeight,
      textColor: root.textColor,
      background: root.backgroundSpec,
      anchorX: root.anchorX,
      anchorY: root.anchorY,
      marginX: root.marginX,
      marginY: root.marginY
    }
    var serialized = TitleModel.serializeConfig(cfg)
    Quickshell.execDetached([
      "bash", "-c",
      "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"",
      "--",
      serialized,
      root.configPath
    ])
  }

  function open(payloadJson) {
    var p = ({})
    try { p = JSON.parse(payloadJson || "{}") } catch (e) { p = ({}) }
    if (p.text) root.text = p.text
    if (p.edit === true) {
      root.editing = true
    }
    root.opened = true
  }

  function close() {
    if (root.editing) {
      root.saveConfig()
      root.editing = false
    }
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "xifan.overlay-title")
  }

  function toggle() {
    if (root.opened && !root.editing) {
      root.close()
    } else if (root.opened && root.editing) {
      root.saveConfig()
      root.editing = false
    } else {
      root.open("{}")
    }
  }

  function toggleEdit() {
    if (!root.opened) {
      root.opened = true
      root.editing = true
    } else {
      if (root.editing) {
        root.saveConfig()
        root.editing = false
      } else {
        root.editing = true
      }
    }
  }

  IpcHandler {
    target: "xifan.overlay-title"

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
      root.editing = false
      return "open"
    }

    function hide(): string {
      root.close()
      return "closed"
    }

    function state(): string {
      if (!root.opened) return "closed"
      return root.editing ? "editing" : "open"
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-screenrecord-title"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.editing && root.inlineEditing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Broadcast mode: 100% click-through mask.
    // Edit mode: catch pointer events on the card and HUD toolbar.
    mask: root.editing ? editMask : emptyMask

    Region { id: emptyMask }
    Region {
      id: editMask
      item: hudContainer
    }

    Item {
      id: hudContainer
      anchors.fill: parent

      // Positioned card container
      Item {
        id: card
        width: Math.min(contentRow.implicitWidth + 32, parent.width - 48)
        height: contentRow.implicitHeight + (root.editing ? 42 : 12)

        x: root.anchorX === "left" ? root.marginX
            : root.anchorX === "right" ? parent.width - root.marginX - width
            : Math.round((parent.width - width) / 2)
        y: root.anchorY === "top" ? root.marginY
            : root.anchorY === "bottom" ? parent.height - root.marginY - height
            : Math.round((parent.height - height) / 2)

        // Edit mode HUD backdrop & border
        Rectangle {
          id: hudBorder
          visible: root.editing
          anchors.fill: parent
          radius: Style.cornerRadius
          color: Util.alpha(Color.popups.background, 0.75)
          border.color: Color.accent
          border.width: 1.5

          // Top action bar in edit mode
          Row {
            id: actionBar
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 8
            spacing: 6

            Rectangle {
              width: doneText.implicitWidth + 12
              height: 22
              radius: 4
              color: Color.accent
              Text {
                id: doneText
                anchors.centerIn: parent
                text: "✓ 锁定 (Enter)"
                font.pixelSize: 11
                font.bold: true
                color: Color.background
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.saveConfig()
                  root.editing = false
                }
              }
            }

            Rectangle {
              width: fontMinus.implicitWidth + 10
              height: 22
              radius: 4
              color: Util.alpha(Color.foreground, 0.15)
              Text {
                id: fontMinus
                anchors.centerIn: parent
                text: "A-"
                font.pixelSize: 11
                font.bold: true
                color: Color.foreground
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fontSize = Math.max(12, root.fontSize - 2)
              }
            }

            Rectangle {
              width: fontPlus.implicitWidth + 10
              height: 22
              radius: 4
              color: Util.alpha(Color.foreground, 0.15)
              Text {
                id: fontPlus
                anchors.centerIn: parent
                text: "A+"
                font.pixelSize: 11
                font.bold: true
                color: Color.foreground
              }
              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fontSize = Math.min(120, root.fontSize + 2)
              }
            }
          }

          // Move drag grip
          MouseArea {
            id: dragArea
            anchors.fill: parent
            anchors.topMargin: 26
            cursorShape: Qt.SizeAllCursor
            hoverEnabled: true

            property real startGlobalX: 0
            property real startGlobalY: 0
            property int startMarginX: 0
            property int startMarginY: 0

            onPressed: function(mouse) {
              var p = dragArea.mapToItem(null, mouse.x, mouse.y)
              startGlobalX = p.x
              startGlobalY = p.y
              startMarginX = root.marginX
              startMarginY = root.marginY
            }

            onPositionChanged: function(mouse) {
              if (mouse.buttons & Qt.LeftButton) {
                var p = dragArea.mapToItem(null, mouse.x, mouse.y)
                var dx = Math.round(p.x - startGlobalX)
                var dy = Math.round(p.y - startGlobalY)
                if (root.anchorX === "right") root.marginX = Math.max(0, startMarginX - dx)
                else root.marginX = Math.max(0, startMarginX + dx)

                if (root.anchorY === "bottom") root.marginY = Math.max(0, startMarginY - dy)
                else root.marginY = Math.max(0, startMarginY + dy)
              }
            }

            onWheel: function(wheel) {
              if (wheel.angleDelta.y > 0) root.fontSize = Math.min(120, root.fontSize + 2)
              else if (wheel.angleDelta.y < 0) root.fontSize = Math.max(12, root.fontSize - 2)
            }

            onDoubleClicked: {
              root.inlineEditing = true
              Qt.callLater(function() { textInput.forceActiveFocus() })
            }
          }
        }

        // Content Row
        Item {
          id: contentRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.bottomMargin: root.editing ? 8 : 0
          anchors.leftMargin: root.editing ? 12 : 0
          anchors.rightMargin: root.editing ? 12 : 0
          implicitWidth: textMetrics.tightBoundingRect.width
          implicitHeight: Math.max(textMetrics.tightBoundingRect.height, root.fontSize * 1.2)

          // Normal outlined display text (when not inline editing)
          Text {
            id: displayText
            visible: !root.inlineEditing
            anchors.fill: parent
            text: root.text
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            style: Text.Outline
            styleColor: Util.alpha(Qt.rgba(0, 0, 0, 1), 0.95)
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: root.anchorX === "right" ? Text.AlignRight : Text.AlignLeft
          }

          // Inline text input (when double clicked in edit mode)
          TextInput {
            id: textInput
            visible: root.editing && root.inlineEditing
            anchors.fill: parent
            text: root.text
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: root.anchorX === "right" ? Text.AlignRight : Text.AlignLeft
            selectByMouse: true

            onTextEdited: root.text = textInput.text

            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.text = textInput.text
                root.inlineEditing = false
                root.saveConfig()
                root.editing = false
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

  TextMetrics {
    id: textMetrics
    text: root.text || " "
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    font.weight: root.fontWeight
  }
}
