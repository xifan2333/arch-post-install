import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "xifan.github-alerts"
  ipcTarget: "xifan.github-alerts"
  manageIpc: false

  property int unreadCount: 0
  property var notifications: []
  property string lastUpdated: ""
  property bool isRefreshing: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string iconText: ""

  readonly property string scriptPath: {
    var raw = Qt.resolvedUrl("check.sh").toString();
    return raw.replace(/^file:\/\//, "");
  }

  readonly property string stateFilePath: {
    var stateHome = Quickshell.env("XDG_STATE_HOME");
    if (!stateHome) {
      stateHome = Quickshell.env("HOME") + "/.local/state";
    }
    return stateHome + "/omarchy/gh-alerts.json";
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (checkProc.running)
      return;
    root.isRefreshing = true;
    checkProc.running = true;
  }

  function markAllRead() {
    if (markReadProc.running)
      return;
    markReadProc.running = true;
  }

  function parsePayload(jsonStr) {
    if (!jsonStr)
      return;
    try {
      var data = JSON.parse(jsonStr);
      root.unreadCount = typeof data.count === "number" ? data.count : 0;
      root.notifications = Array.isArray(data.items) ? data.items : [];
      if (data.updated_at)
        root.lastUpdated = data.updated_at;
    } catch (e) {
    }
  }

  function typeIcon(type) {
    if (type === "PullRequest")
      return " ";
    if (type === "Issue")
      return " ";
    if (type === "Release")
      return " ";
    if (type === "Commit")
      return " ";
    return " ";
  }

  function timeAgo(isoString) {
    if (!isoString)
      return "";
    var then = new Date(isoString).getTime();
    var now = new Date().getTime();
    var diffSec = Math.floor((now - then) / 1000);
    if (isNaN(diffSec) || diffSec < 0)
      return "";
    if (diffSec < 60)
      return "just now";
    var diffMin = Math.floor(diffSec / 60);
    if (diffMin < 60)
      return diffMin + "m ago";
    var diffHours = Math.floor(diffMin / 60);
    if (diffHours < 24)
      return diffHours + "h ago";
    var diffDays = Math.floor(diffHours / 24);
    return diffDays + "d ago";
  }

  FileView {
    id: stateWatch
    path: root.stateFilePath
    watchChanges: true
    printErrors: false
    onLoaded: root.parsePayload(text())
    onFileChanged: reload()
  }

  Process {
    id: checkProc
    command: [root.scriptPath]
    stdout: SplitParser {
      onRead: function (data) {
        root.parsePayload(data);
      }
    }
    onExited: root.isRefreshing = false
  }

  Process {
    id: markReadProc
    command: [root.scriptPath, "mark-read"]
    stdout: SplitParser {
      onRead: function (data) {
        root.parsePayload(data);
      }
    }
  }

  Timer {
    interval: 120000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.iconText
    onPressed: function (b) {
      if (b === Qt.RightButton) {
        root.markAllRead();
      } else if (b === Qt.MiddleButton) {
        root.refresh();
      } else {
        root.toggle();
      }
    }

    Rectangle {
      id: badge
      visible: root.unreadCount > 0
      anchors.top: parent.top
      anchors.topMargin: Style.space(3)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(3)
      width: Math.max(badgeText.implicitWidth + Style.space(6), Style.space(14))
      height: Style.space(14)
      radius: height / 2
      color: Color.urgent

      Text {
        id: badgeText
        anchors.centerIn: parent
        text: root.unreadCount > 99 ? "99+" : String(root.unreadCount)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        color: "#ffffff"
      }
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
    function refresh(): string {
      root.refresh();
      return "refreshing";
    }
    function markRead(): string {
      root.markAllRead();
      return "marked";
    }
    function status(): string {
      return root.unreadCount + " notifications";
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(mainColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function (direction) {
        root.switchPanel(direction);
      }

      Column {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // Hero Header
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, headerActions.implicitHeight)

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
            anchors.right: headerActions.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "GitHub Alerts"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.unreadCount > 0 ? root.unreadCount + " unread notification" + (root.unreadCount > 1 ? "s" : "") : "All caught up"
              color: root.unreadCount > 0 ? Color.urgent : Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: headerActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            PanelActionButton {
              iconText: ""
              tooltipText: "Refresh (Middle click on icon)"
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.isRefreshing
              onClicked: root.refresh()
            }

            PanelActionButton {
              iconText: ""
              tooltipText: "Mark all read (Right click on icon)"
              foreground: root.foreground
              hoverColor: Color.urgent
              fontFamily: root.fontFamily
              enabled: root.unreadCount > 0
              onClicked: root.markAllRead()
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        // Empty state
        Item {
          width: parent.width
          implicitHeight: Style.space(80)
          visible: root.notifications.length === 0

          Column {
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: ""
              color: Qt.darker(root.foreground, 1.8)
              font.family: root.fontFamily
              font.pixelSize: Style.space(28)
            }

            Text {
              anchors.horizontalCenter: parent.horizontalCenter
              text: "No new notifications"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // Notification item list
        Column {
          width: parent.width
          spacing: Style.space(8)
          visible: root.notifications.length > 0

          Repeater {
            model: root.notifications.slice(0, 10)

            Rectangle {
              id: itemCard
              width: parent.width
              implicitHeight: itemContent.implicitHeight + Style.space(16)
              radius: Style.cornerRadius
              color: itemMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : Util.alpha(root.foreground, 0.03)

              Behavior on color {
                ColorAnimation {
                  duration: 60
                }
              }

              MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.url) {
                    Qt.openUrlExternally(modelData.url);
                    root.close();
                  }
                }
              }

              Column {
                id: itemContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(8)
                spacing: Style.space(4)

                Row {
                  width: parent.width
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText
                    text: root.typeIcon(modelData.type)
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: modelData.repo || ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - Style.space(160)
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Item {
                    // Spacer
                    width: Style.space(2)
                    height: 1
                  }

                  Rectangle {
                    radius: Style.space(3)
                    color: Util.alpha(Color.accent, 0.15)
                    implicitWidth: reasonText.implicitWidth + Style.space(6)
                    implicitHeight: reasonText.implicitHeight + Style.space(2)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      id: reasonText
                      anchors.centerIn: parent
                      text: modelData.reason || ""
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Text {
                    text: root.timeAgo(modelData.updated_at)
                    color: Qt.darker(root.foreground, 1.8)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                Text {
                  width: parent.width
                  text: modelData.title || ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                  maximumLineCount: 2
                  wrapMode: Text.Wrap
                }
              }
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
          visible: root.notifications.length > 0
        }

        // Bottom link to open all notifications on GitHub
        Rectangle {
          width: parent.width
          implicitHeight: Style.space(28)
          radius: Style.cornerRadius
          color: bottomMouse.containsMouse ? Util.alpha(root.foreground, 0.08) : "transparent"
          visible: root.notifications.length > 0

          Behavior on color {
            ColorAnimation {
              duration: 60
            }
          }

          MouseArea {
            id: bottomMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              Qt.openUrlExternally("https://github.com/notifications");
              root.close();
            }
          }

          Row {
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              text: ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              text: "Open All on GitHub"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }
      }
    }
  }
}
