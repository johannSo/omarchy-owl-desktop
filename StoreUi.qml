import QtQuick

// The store's colors and sizes, the launcher's for its screens (Theme.kt's
// ThemePalette and TextSize), in px at the desktop's scale.
QtObject {
  property real dp: 1
  // Every frame's corner radius in px: the desktop's.
  property real corner: 0
  property string font: "monospace"
  property color background
  property color surface
  property color overlay
  property color foreground
  property color muted
  property color accent
  property color border
  property color red
  property color green
  readonly property color selected: Qt.rgba(accent.r, accent.g, accent.b, 0.15)
  // TextSize: Small, Body, Item, Title.
  readonly property real small: 12 * dp
  readonly property real body: 14 * dp
  readonly property real item: 15 * dp
  readonly property real title: 18 * dp
  function color(name: string): color { return name === "accent" ? accent : name === "green" ? green : name === "red" ? red : muted }
}
