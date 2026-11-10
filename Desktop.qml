import QtQuick
import Quickshell

// One monitor: its desktop of widgets, the panel a widget's screen { } opens
// in over everything there, and the store's.
Scope {
  id: root

  required property var modelData
  required property var app
  required property var host

  readonly property alias desk: deskWindow

  DesktopWindow {
    id: deskWindow
    screen: root.modelData
    app: root.app
    host: root.host
  }

  ScreenWindow {
    screen: root.modelData
    app: root.app
    widget: deskWindow.screenWidget
    dp: deskWindow.dp
  }

  StoreWindow {
    screen: root.modelData
    app: root.app
    desk: deskWindow
    dp: deskWindow.dp
  }
}
