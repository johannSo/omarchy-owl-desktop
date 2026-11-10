pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "owl" as Owl
import "Layout.js" as Layout

// One widget on the desktop, framed as Omalauncher frames it on the phone's
// home screen (Theme.kt's Modifier.tile): the theme's background as glass over
// the wallpaper, the widget's own background over that, its nodes inside its
// padding, and a square outline in the theme's border color on top, the
// accent while it's being typed into or arranged. A face has no frame: it is
// the whole screen, behind the tiles.
Item {
  id: tile

  required property string modelData
  required property var desk
  required property var app
  required property var host
  required property var ghost
  required property var outline

  signal settle()

  readonly property string file: tile.modelData
  readonly property alias owl: live
  readonly property var style: tile.app.style
  readonly property real dp: tile.desk.dp
  readonly property var cell: tile.desk.cells[tile.file] || null
  readonly property bool face: live.isFace
  readonly property bool placed: !!tile.cell && !tile.cell.hidden && Layout.isFace(tile.cell) === tile.face
  readonly property bool isSelected: tile.desk.editing && tile.desk.selected === tile.file
  // In grid cells, as the widget sees them: its tile's, or for a face the whole grid.
  readonly property int cols: tile.face ? tile.desk.columns : tile.cell && !Layout.isFace(tile.cell) ? tile.cell.w : live.size[0]
  readonly property int rowCount: tile.face ? tile.desk.rows : tile.cell && !Layout.isFace(tile.cell) ? tile.cell.h : live.size[1]
  readonly property var r: tile.face || !tile.cell || Layout.isFace(tile.cell)
    ? { x: 0, y: 0, width: tile.desk.width, height: tile.desk.height } : tile.desk.cellRect(tile.cell)

  // While dragging: how far the pointer has moved the tile.
  property point moved: Qt.point(0, 0)

  visible: tile.placed
  x: tile.r.x + tile.moved.x
  y: tile.r.y + tile.moved.y
  width: tile.r.width
  height: tile.r.height
  z: tile.face ? -1 : tile.moved.x || tile.moved.y ? 2 : tile.isSelected ? 1 : 0

  // Where it takes the pointer: all of a tile; a face only when something in
  // it takes taps or typing, so a plain one leaves the desktop's clicks alone.
  readonly property bool takesPointer: tile.placed && (!tile.face || tile.interactive)
  property Region region: Region { item: tile.takesPointer ? tile : null }

  readonly property bool interactive: {
    var t = live.tree
    if (!t) return false
    if (t.onTap) return true
    var stack = t.children.slice()
    while (stack.length) {
      var n = stack.pop()
      if (!n) continue
      if (n.h && Object.keys(n.h).length) return true
      if (["Input", "Slider", "Terminal", "Browser"].indexOf(String(n.kind)) >= 0) return true
      if (n.c) for (var i = 0; i < n.c.length; i++) stack.push(n.c[i])
    }
    return false
  }

  // The accent while it has the keyboard, as Hyprland's active border.
  readonly property bool typing: {
    var f = tile.Window.activeFocusItem
    while (f) { if (f === tile) return true; f = f.parent }
    return false
  }
  readonly property bool focused: tile.isSelected || (tile.typing && !tile.face)

  // ------------------------------------------------------------ packages

  // A widget's `requires { pacman: [...] }`: while any is missing, the tile
  // says `needs jq` with an install button instead of running it, as on the phone.
  property var missing: []
  property bool installing: false
  readonly property var packages: live.program && live.program.requires && live.program.requires.pacman
    ? live.program.requires.pacman : []
  onPackagesChanged: tile.checkPackages()

  function checkPackages() {
    if (!tile.packages.length) { tile.missing = []; return }
    tile.app.run(["bash", "-c", "command -v pacman >/dev/null || exit 0; pacman -T \"$@\"; exit 0", "requires"].concat(tile.packages), function(code, out) {
      var next = out.split("\n").map(function(l) { return l.trim() }).filter(function(l) { return l !== "" })
      if (JSON.stringify(next) !== JSON.stringify(tile.missing)) tile.missing = next
    })
  }
  Timer { interval: 10000; repeat: true; running: tile.missing.length > 0 && tile.placed; onTriggered: tile.checkPackages() }

  function installPackages() {
    tile.installing = true
    tile.app.widgets(["packages", "--terminal", tile.app.dir + "/" + tile.file], function() {
      tile.installing = false
      tile.checkPackages()
    })
  }

  // ------------------------------------------------------------ the widget

  // The glass: the theme's background, as much as widgets.opacity says.
  Rectangle {
    anchors.fill: parent
    visible: !tile.face
    color: tile.app.alpha(tile.app.ink("background"), tile.style.opacity)
  }

  // The widget's own `background:`, over the glass: a color, or since owl 10 a gradient.
  Owl.OwlNode {
    anchors.fill: parent
    visible: !live.error && !!live.tree && !!live.tree.background && tile.missing.length === 0
    widget: live
    node: live.tree && live.tree.background ? { kind: "Box", p: { background: live.tree.background }, h: {}, a: {}, c: [], level: live.level } : null
  }

  Owl.OwlWidget {
    id: live
    anchors.fill: parent
    anchors.margins: (live.program ? live.program.padding : 12) * tile.dp
    path: tile.app.dir + "/" + tile.file
    host: tile.host
    palette: tile.app.palette
    active: tile.desk.active && tile.placed && tile.missing.length === 0
    cols: tile.cols
    rows: tile.rowCount
    dp: tile.dp
    screenWidth: tile.face ? tile.desk.width : tile.desk.screenAreaWidth
    screenHeight: tile.face ? tile.desk.height : tile.desk.screenAreaHeight
    onProgramChanged: tile.settle()
    onErrorChanged: tile.settle()
    onScreenRequested: tile.desk.screenWidget = live
    onScreenClosed: if (tile.desk.screenWidget === live) tile.desk.screenWidget = null
  }

  TapHandler {
    enabled: !tile.desk.editing && !!(live.tree && live.tree.onTap) && tile.missing.length === 0
    onTapped: (p) => live.tree.onTap((p.position.x - live.x) / live.dp, (p.position.y - live.y) / live.dp)
  }

  // Several nodes at the top lay out as the launcher lays them out: a Column.
  Owl.OwlNode {
    anchors.fill: live
    visible: !live.error && !!live.tree && tile.missing.length === 0
    enabled: !tile.desk.editing
    widget: live
    node: !live.tree ? null : live.tree.children.length === 1 ? live.tree.children[0]
      : { kind: "Column", p: { gap: 0 }, h: {}, a: {}, c: live.tree.children }
  }

  // A file that doesn't compile: its name in red and the error under it, as on the phone.
  Column {
    anchors.fill: parent
    anchors.margins: 12 * tile.dp
    visible: !!live.error
    spacing: 0
    clip: true
    Text {
      width: parent.width
      text: live.fileName
      textFormat: Text.PlainText
      color: tile.app.ink("red")
      font.family: tile.app.font
      font.pixelSize: 14 * tile.dp
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: live.error
      textFormat: Text.PlainText
      color: tile.app.ink("muted")
      font.family: tile.app.font
      font.pixelSize: 12 * tile.dp
      wrapMode: Text.Wrap
    }
  }

  // A package it needs is missing: the widget's name, what it needs, and install.
  Column {
    anchors.fill: parent
    anchors.margins: 12 * tile.dp
    visible: !live.error && tile.missing.length > 0
    spacing: 6 * tile.dp
    clip: true
    Text {
      width: parent.width
      text: live.name
      textFormat: Text.PlainText
      color: tile.app.ink("muted")
      font.family: tile.app.font
      font.pixelSize: 14 * tile.dp
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: "needs " + tile.missing.join(", ")
      textFormat: Text.PlainText
      color: tile.app.ink("foreground")
      font.family: tile.app.font
      font.pixelSize: 14 * tile.dp
      wrapMode: Text.Wrap
    }
    Rectangle {
      width: installLabel.implicitWidth + 20 * tile.dp
      height: installLabel.implicitHeight + 12 * tile.dp
      color: "transparent"
      border.width: Math.max(1, tile.dp)
      border.color: tile.app.ink("accent")
      Text {
        id: installLabel
        anchors.centerIn: parent
        text: tile.installing ? "installing…" : "install"
        color: tile.app.ink("accent")
        font.family: tile.app.font
        font.pixelSize: 14 * tile.dp
      }
      MouseArea {
        anchors.fill: parent
        enabled: !tile.installing && !tile.desk.editing
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.installPackages()
      }
    }
  }

  // The outline, on top: widgets.border-width in the theme's border color, or
  // the focused width in the accent.
  Rectangle {
    anchors.fill: parent
    visible: !tile.face && (tile.focused || tile.style.borderWidth > 0)
    color: "transparent"
    border.width: (tile.focused ? Math.max(tile.style.borderWidth, 2) : tile.style.borderWidth) * tile.dp
    border.color: tile.focused ? tile.app.settingColor(tile.style.borderFocused, "accent") : tile.app.settingColor(tile.style.border, "muted")
  }

  // A face being arranged shows where it is with the accent too.
  Rectangle {
    anchors.fill: parent
    visible: tile.face && tile.isSelected
    color: "transparent"
    border.width: Math.max(2, 3 * tile.dp)
    border.color: tile.app.settingColor(tile.style.borderFocused, "accent")
  }

  // ------------------------------------------------------------ arranging

  // Hold or right-click to arrange, as a long press does on the phone's home screen.
  TapHandler {
    enabled: !tile.desk.editing
    onLongPressed: tile.desk.arrange(tile.file)
  }
  TapHandler {
    enabled: !tile.desk.editing
    acceptedButtons: Qt.RightButton
    onTapped: tile.desk.arrange(tile.file)
  }

  // Arranging: the whole tile drags; nothing inside it is live. A face stays
  // put, and a click on it is a click beside the tiles.
  MouseArea {
    anchors.fill: parent
    visible: tile.desk.editing
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: tile.face ? Qt.ArrowCursor : pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property point pressedAt
    property bool dragged: false
    onPressed: (m) => {
      if (tile.face) return
      pressedAt = mapToItem(tile.parent, m.x, m.y)
      dragged = false
      tile.desk.selected = tile.file
      tile.desk.holding = true
    }
    onClicked: if (tile.face) tile.desk.finishEditing()
    onPositionChanged: (m) => {
      if (tile.face || !pressed || !tile.cell) return
      var p = mapToItem(tile.parent, m.x, m.y)
      tile.moved = Qt.point(p.x - pressedAt.x, p.y - pressedAt.y)
      dragged = true
      var g = tile.desk.grid
      tile.ghost.cell = { x: Math.round(tile.cell.x + tile.moved.x / g.cellW), y: Math.round(tile.cell.y + tile.moved.y / g.cellH), w: tile.cell.w, h: tile.cell.h }
      tile.ghost.fits = !!Layout.move(tile.desk.cells, tile.file, tile.ghost.cell.x, tile.ghost.cell.y, tile.desk.columns, tile.desk.rows, tile.desk.files)
    }
    onReleased: {
      if (tile.face) return
      if (tile.ghost.cell && tile.ghost.fits) tile.desk.moveTo(tile.file, tile.ghost.cell.x, tile.ghost.cell.y)
      tile.moved = Qt.point(0, 0)
      tile.ghost.cell = null
      tile.desk.holding = false
    }
    onCanceled: { tile.moved = Qt.point(0, 0); tile.ghost.cell = null; tile.desk.holding = false }
  }

  // The selected tile resizes from any edge, in whole cells, as on the phone:
  // a handle in the middle of each side, the whole side to grab.
  Repeater {
    model: tile.isSelected && !tile.face ? ["left", "top", "right", "bottom"] : []
    delegate: Item {
      id: side
      required property string modelData
      readonly property bool across: side.modelData === "left" || side.modelData === "right"
      readonly property real grab: 8
      x: side.modelData === "left" ? -grab : side.modelData === "right" ? tile.width - grab : 0
      y: side.modelData === "top" ? -grab : side.modelData === "bottom" ? tile.height - grab : 0
      width: side.across ? 2 * grab : tile.width
      height: side.across ? tile.height : 2 * grab
      z: 3

      Rectangle {
        anchors.centerIn: parent
        visible: !tile.desk.holding
        width: Math.max(12, 14 * tile.dp)
        height: width
        radius: width / 2
        color: tile.app.ink("accent")
        border.width: 2
        border.color: tile.app.ink("background")
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: side.across ? Qt.SizeHorCursor : Qt.SizeVerCursor
        property point pressedAt
        onPressed: (m) => { pressedAt = mapToItem(tile.parent, m.x, m.y); tile.desk.holding = true }
        onPositionChanged: (m) => {
          if (!pressed || !tile.cell) return
          var p = mapToItem(tile.parent, m.x, m.y)
          var dx = side.across ? p.x - pressedAt.x : 0, dy = side.across ? 0 : p.y - pressedAt.y
          var e = {}
          e[side.modelData] = true
          var g = tile.desk.grid, c = tile.cell, min = live.minSize
          // The outline: the tile's edges, the dragged one at the pointer,
          // never smaller than minSize nor off the grid.
          var minW = Layout.rect(g, { x: c.x, y: c.y, w: min[0], h: min[1] })
          var l = tile.r.x, t = tile.r.y, rr = tile.r.x + tile.r.width, b = tile.r.y + tile.r.height
          var right = Layout.rect(g, { x: 0, y: 0, w: tile.desk.columns, h: tile.desk.rows })
          if (e.left) l = Math.max(right.x, Math.min(l + dx, rr - minW.width))
          if (e.right) rr = Math.min(right.x + right.width, Math.max(rr + dx, l + minW.width))
          if (e.top) t = Math.max(right.y, Math.min(t + dy, b - minW.height))
          if (e.bottom) b = Math.min(right.y + right.height, Math.max(b + dy, t + minW.height))
          tile.outline.r = Qt.rect(l, t, rr - l, b - t)
          tile.ghost.cell = Layout.edge(c, e, Math.round(dx / g.cellW), Math.round(dy / g.cellH), min, tile.desk.columns, tile.desk.rows)
          tile.ghost.fits = !!Layout.place(tile.desk.cells, tile.file, tile.ghost.cell, tile.desk.columns, tile.desk.rows, tile.desk.files)
        }
        function done() {
          tile.outline.r = Qt.rect(0, 0, 0, 0)
          tile.ghost.cell = null
          tile.desk.holding = false
        }
        onReleased: {
          if (tile.ghost.cell && tile.ghost.fits) tile.desk.placeAt(tile.file, tile.ghost.cell)
          done()
        }
        onCanceled: done()
      }
    }
  }
}
