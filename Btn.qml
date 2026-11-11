import QtQuick

// The desktop's one button, for arranging: plain, or primary (the thing to do
// here). Omalauncher's desktop app's, in the theme's colors.
Rectangle {
  id: root

  required property var app
  property string text: ""
  property bool primary: false

  signal clicked()

  readonly property color accent: root.app.ink("accent")
  readonly property color fg: root.app.ink("foreground")
  readonly property color onAccent: (0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b) > 0.55 ? "#111111" : "#ffffff"

  implicitWidth: label.implicitWidth + 24
  implicitHeight: 28
  radius: root.app.corner
  color: root.primary ? (mouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent)
    : mouse.containsMouse ? root.app.alpha(root.fg, 0.08) : "transparent"
  border.width: 1
  border.color: root.primary ? root.accent : root.app.alpha(root.app.ink("muted"), 0.8)

  Text {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.primary ? root.onAccent : root.fg
    font.family: root.app.font
    font.pixelSize: 12
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
