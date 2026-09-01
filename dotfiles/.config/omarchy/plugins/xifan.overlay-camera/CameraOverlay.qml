// Webcam PiP HUD overlay. Uses Qt Multimedia (no GTK / GStreamer process).
// Broadcast mode is click-through. Super+Shift+V enters HUD edit: drag to
// move, wheel to scale, double-click to cycle 1:1 / 4:3 / 16:9 / 3:4 / 9:16.

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "CameraModel.js" as CameraModel

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool editing: false

  property string device: "auto"
  property int widthPx: 200
  property int heightPx: 150
  property int captureWidth: 640
  property int captureHeight: 480
  property int fps: 30
  property string anchorX: "right"
  property string anchorY: "bottom"
  property int marginX: 0
  property int marginY: 0
  property real borderWidth: 1.5
  property string aspect: "4:3"

  readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/screenrecord/camera.conf"

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
    var cfg = CameraModel.parseConfig(raw);
    root.device = cfg.device;
    root.widthPx = cfg.width;
    root.heightPx = cfg.height;
    root.captureWidth = cfg.captureWidth;
    root.captureHeight = cfg.captureHeight;
    root.fps = cfg.fps;
    root.anchorX = cfg.anchorX;
    root.anchorY = cfg.anchorY;
    root.marginX = cfg.marginX;
    root.marginY = cfg.marginY;
    root.borderWidth = cfg.borderWidth;
    root.aspect = cfg.aspect;
    root.applyAspectSize(root.widthPx);
  }

  function saveConfig() {
    var cfg = {
      device: root.device,
      width: root.widthPx,
      height: root.heightPx,
      captureWidth: root.captureWidth,
      captureHeight: root.captureHeight,
      fps: root.fps,
      anchorX: root.anchorX,
      anchorY: root.anchorY,
      marginX: root.marginX,
      marginY: root.marginY,
      borderWidth: root.borderWidth,
      aspect: root.aspect
    };
    var serialized = CameraModel.serializeConfig(cfg);
    Quickshell.execDetached(["bash", "-c", "mkdir -p \"$(dirname \"$2\")\" && printf '%s' \"$1\" > \"$2\"", "--", serialized, root.configPath]);
  }

  function applyAspectSize(widthHint) {
    var sized = CameraModel.sizeForAspect(root.aspect, widthHint, 80, 640);
    root.widthPx = sized.width;
    root.heightPx = sized.height;
  }

  function cycleAspect() {
    root.aspect = CameraModel.nextAspect(root.aspect);
    root.applyAspectSize(root.widthPx);
  }

  function applyCamera() {
    var dev = CameraModel.pickDevice(mediaDevices.videoInputs, root.device);
    if (!dev)
      return;
    camera.cameraDevice = dev;
    var fmt = CameraModel.pickFormat(dev, root.captureWidth, root.captureHeight, root.fps);
    if (fmt)
      camera.cameraFormat = fmt;
  }

  function lockEdit() {
    root.saveConfig();
    root.editing = false;
  }

  function toggle() {
    if (root.opened && !root.editing) {
      root.opened = false;
    } else if (root.opened && root.editing) {
      root.lockEdit();
    } else {
      root.opened = true;
    }
  }

  function toggleEdit() {
    if (!root.opened) {
      root.opened = true;
      root.editing = true;
    } else if (root.editing) {
      root.lockEdit();
    } else {
      root.editing = true;
    }
  }

  onOpenedChanged: {
    if (root.opened) {
      root.applyCamera();
      camera.active = true;
    } else {
      camera.active = false;
      root.editing = false;
    }
  }

  MediaDevices {
    id: mediaDevices
    onVideoInputsChanged: if (root.opened)
      root.applyCamera()
  }

  CaptureSession {
    id: session
    camera: camera
    videoOutput: preview
  }

  Camera {
    id: camera
    active: false
  }

  IpcHandler {
    target: "xifan.overlay-camera"

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
      root.editing = false;
      return "open";
    }
    function hide(): string {
      root.opened = false;
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
    WlrLayershell.namespace: "omarchy-screenrecord-camera"
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
          root.lockEdit();
          event.accepted = true;
        }
      }

      Item {
        id: card
        width: root.widthPx + (root.editing ? 8 : 0)
        height: root.heightPx + (root.editing ? 8 : 0)
        clip: true

        x: root.anchorX === "left" ? root.marginX : root.anchorX === "right" ? parent.width - root.marginX - width : Math.round((parent.width - width) / 2)
        y: root.anchorY === "top" ? root.marginY : root.anchorY === "bottom" ? parent.height - root.marginY - height : Math.round((parent.height - height) / 2)

        Rectangle {
          id: hudBorder
          visible: root.editing
          anchors.fill: parent
          radius: Style.cornerRadius
          color: Util.alpha(Color.popups.background, 0.35)
          border.color: Color.accent
          border.width: 1.5
        }

        VideoOutput {
          id: preview
          anchors.centerIn: parent
          width: root.widthPx
          height: root.heightPx
          fillMode: VideoOutput.PreserveAspectCrop
          mirrored: true
        }

        Rectangle {
          visible: root.borderWidth > 0
          anchors.centerIn: parent
          width: root.widthPx
          height: root.heightPx
          color: "transparent"
          border.color: Qt.rgba(1, 1, 1, 0.22)
          border.width: root.borderWidth
        }

        Text {
          visible: root.editing
          anchors.left: preview.left
          anchors.top: preview.top
          anchors.margins: 6
          text: root.aspect
          color: Color.accent
          font.pixelSize: 12
          font.weight: Font.Bold
          style: Text.Outline
          styleColor: Util.alpha(Qt.rgba(0, 0, 0, 1), 0.8)
        }

        MouseArea {
          id: dragArea
          visible: root.editing
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
            var step = wheel.angleDelta.y > 0 ? 8 : -8;
            root.applyAspectSize(root.widthPx + step);
          }

          onDoubleClicked: root.cycleAspect()
        }
      }
    }
  }
}
