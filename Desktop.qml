import QtQuick
import Quickshell

// One monitor: its desktop of widgets, and the panel a widget's screen { }
// opens in over everything there.
Scope {
  id: root

  required property var modelData
  required property var app
  required property var host

  readonly property alias desk: desk

  DesktopWindow {
    id: desk
    screen: root.modelData
    app: root.app
    host: root.host
  }

  ScreenWindow {
    screen: root.modelData
    app: root.app
    widget: desk.screenWidget
    dp: desk.dp
  }
}
