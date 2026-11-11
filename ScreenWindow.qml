pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "owl" as Owl

// A widget's screen { } (owl 5), opened with screen(): over everything on its
// monitor, framed as the launcher frames it (Components.kt's OverlayPanel):
// the theme's background as a scrim, a panel in the accent with the screen's
// title and a ✕, the nodes under them. A phone's width, since that's what a
// screen is written for. A click on the scrim, the ✕ or Escape closes it.
PanelWindow {
  id: win

  required property var app
  property var widget: null
  property real dp: 1

  readonly property var tree: win.widget ? win.widget.screenTree : null

  visible: !!win.widget && !!win.tree
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "owl-desktop-screen"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  exclusionMode: ExclusionMode.Normal
  anchors { top: true; bottom: true; left: true; right: true }

  readonly property real gap: win.app.style.gapsOut * win.dp

  function close() { if (win.widget) win.widget.closeScreen() }

  // The scrim: the theme's background at 0.9, as the launcher's Palette.overlay.
  Rectangle {
    anchors.fill: parent
    color: win.app.alpha(win.app.ink("background"), 0.9)
    MouseArea { anchors.fill: parent; onClicked: win.close() }
  }

  Rectangle {
    id: card
    radius: win.app.corner
    anchors.centerIn: parent
    width: Math.min(parent.width - 2 * win.gap, 400 * win.dp)
    height: parent.height - 2 * win.gap
    color: win.app.ink("background")
    border.width: 2 * win.dp
    border.color: win.app.ink("accent")
    focus: win.visible
    Keys.onEscapePressed: win.close()

    // Clicks inside stay inside.
    MouseArea { anchors.fill: parent }

    Item {
      id: header
      x: (2 + 12) * win.dp
      y: (2 + 12) * win.dp
      width: card.width - 2 * x
      height: Math.max(title.implicitHeight, closer.implicitHeight)

      Text {
        id: title
        anchors.left: parent.left
        anchors.right: closer.left
        anchors.verticalCenter: parent.verticalCenter
        text: win.tree ? win.tree.title || "" : ""
        textFormat: Text.PlainText
        color: win.app.ink("accent")
        font.family: win.app.font
        font.pixelSize: 18 * win.dp
        elide: Text.ElideRight
      }

      // nf-md-close, in red, as the launcher's panels close.
      Text {
        id: closer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        padding: 8 * win.dp
        rightPadding: 0
        text: "\uDB80\uDD56"
        color: win.app.ink("red")
        font.family: win.app.font
        font.pixelSize: 18 * win.dp
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: win.close()
        }
      }
    }

    Item {
      anchors.fill: parent
      anchors.margins: (2 + 12) * win.dp
      anchors.topMargin: header.y + header.height + 8 * win.dp
      clip: true

      Owl.OwlNode {
        anchors.fill: parent
        widget: win.widget
        node: !win.tree ? null : win.tree.children.length === 1 ? win.tree.children[0]
          : { kind: "Column", p: { gap: 0 }, h: {}, a: {}, c: win.tree.children }
      }
    }
  }
}
