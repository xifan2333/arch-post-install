import QtQuick
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
  property string text: "Recording"
  property string fontFamily: Style.font.menuFamily
  property int fontSize: 36
  property int fontWeight: 700
  property color textColor: Color.foreground
  property color overlayColor: Color.popups.background
  property real overlayOpacity: 0.55
  property real cornerRadius: Style.cornerRadius
  property string anchorX: "left"
  property string anchorY: "top"
  property int marginX: 24
  property int marginY: 24

  // Read + watch ~/.config/screenrecord/title.conf so live edits take effect
  // without restarting the shell.
  FileView {
    id: conf
    path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config"))
          + "/screenrecord/title.conf"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onFileChanged: reload()
  }

  function applyConfig(raw) {
    var cfg = TitleModel.parseConfig(raw)
    root.text = cfg.text
    root.fontFamily = cfg.fontFamily
    root.fontSize = cfg.fontSize
    root.fontWeight = cfg.fontWeight
    root.textColor = cfg.textColor
    root.overlayColor = cfg.background
    root.overlayOpacity = cfg.opacity
    root.anchorX = cfg.anchorX
    root.anchorY = cfg.anchorY
    root.marginX = cfg.marginX
    root.marginY = cfg.marginY
  }

  // IPC surface used by `omarchy-shell shell toggle xifan.overlay-title` and a
  // future capture-router binding. Kept loaded by the manifest, so handlers
  // remain reachable without a cold load.
  IpcHandler {
    target: "xifan.overlay-title"

    function open(payload: string): string {
      var p = ({})
      try { p = JSON.parse(payload || "{}") } catch (e) { p = ({}) }
      if (p.text) root.text = p.text
      if (p.opacity !== undefined && p.opacity !== null) root.overlayOpacity = Number(p.opacity)
      root.opened = true
      return "ok"
    }
    function toggle(): string { root.toggle(); return root.opened ? "open" : "closed" }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
  }

  function open(payloadJson) {
    var p = ({})
    try { p = JSON.parse(payloadJson || "{}") } catch (e) { p = ({}) }
    if (p.text) root.text = p.text
    if (p.opacity !== undefined && p.opacity !== null) root.overlayOpacity = Number(p.opacity)
    root.opened = true
  }

  function close() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "xifan.overlay-title")
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-screenrecord-title"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual-only: empty input region so the card never blocks clicks below.
    mask: Region {}

    // Visible card: spans the full screen width (minus horizontal margin) so
    // the title stays on one line instead of wrapping. No fill, only text with
    // an outline + drop shadow so it stays readable over any frame.
    Item {
      id: card
      width: parent.width - root.marginX * 2
      height: root.cardHeight
      x: root.marginX
      y: root.anchorY === "top" ? root.marginY
          : root.anchorY === "bottom" ? parent.height - root.marginY - height
          : Math.round((parent.height - height) / 2)

      Text {
        anchors.centerIn: parent
        text: root.text
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
        // NoWrap keeps the title on a single line; alignment follows anchor_x.
        wrapMode: Text.NoWrap
        width: parent.width
        horizontalAlignment: root.anchorX === "left" ? Text.AlignLeft
            : root.anchorX === "right" ? Text.AlignRight
            : Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        // Crisp opaque outline keeps the glyph readable over any background;
        // no panel fill behind it.
        style: Text.Outline
        styleColor: Util.alpha(Qt.rgba(0, 0, 0, 1), 0.9)
      }
    }
  }

  // Single-line card height from the text metrics; full width comes from the
  // panel, so the title never wraps.
  readonly property real cardHeight: {
    var m = textMetrics.tightBoundingRect.height
    return m
  }

  TextMetrics {
    id: textMetrics
    text: root.text
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    font.weight: root.fontWeight
  }
}
