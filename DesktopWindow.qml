pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Layout.js" as Layout

// One monitor's desktop: its widgets on Omalauncher's home-screen grid, over
// the wallpaper and under the windows (the layer below them, as the phone's
// tiles sit on its wallpaper). Only the tiles take the pointer: a click beside
// them reaches the desktop under, which opens the wallpaper and theme pickers
// on a double click as before.
//
// Right-click or hold a widget to arrange the desktop, as a long press does on
// the phone: drag a tile to move it, an edge to resize it, and click beside
// the tiles, or press Enter or Escape, when you're done.
PanelWindow {
  id: win

  required property var app
  required property var host

  readonly property string name: win.screen ? String(win.screen.name) : ""

  color: "transparent"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.namespace: "owl-desktop"
  // A click on a widget gives it the keyboard, for its text fields and terminals.
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  // Inside the bar's room, as windows are.
  exclusionMode: ExclusionMode.Normal
  anchors { top: true; bottom: true; left: true; right: true }

  // ------------------------------------------------------------ geometry

  readonly property var style: win.app.style
  // One OWL dp in px, and the launcher's grid at that size.
  readonly property real dp: win.style.scale
  readonly property var grid: Layout.grid(win.width, win.height, win.style.cell * win.dp, win.style.gapsIn * win.dp, win.style.gapsOut * win.dp)
  readonly property int columns: win.grid.columns
  readonly property int rows: win.grid.rows

  function cellRect(c) { return Layout.rect(win.grid, c) }

  // ------------------------------------------------------------ covered

  // While tiled or fullscreen windows cover this monitor's desktop, its
  // widgets stop their sources and animations, as the phone's do on a page
  // that isn't showing; they run again as soon as it shows.
  readonly property var monitor: win.screen ? Hyprland.monitorFor(win.screen) : null
  property int hyprRevision: 0
  readonly property bool covered: {
    void win.hyprRevision
    var ws = win.monitor ? win.monitor.activeWorkspace : null
    if (!ws) return false
    var windows = ws.toplevels ? ws.toplevels.values : []
    for (var i = 0; i < windows.length; i++) {
      var ipc = windows[i].lastIpcObject || {}
      if (ipc.floating === true && !ipc.fullscreen) continue
      // Not read yet: take it as covering until Hyprland says otherwise.
      return true
    }
    return false
  }
  readonly property bool active: win.app.ready && (!win.style.pauseWhenCovered || !win.covered || win.editing)

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      switch (String(event.name)) {
      case "fullscreen": case "openwindow": case "closewindow": case "movewindowv2":
      case "workspacev2": case "focusedmonv2": case "changefloatingmode": case "activespecial":
        hyprRefresh.restart()
      }
    }
  }
  Timer {
    id: hyprRefresh
    interval: 100
    onTriggered: { Hyprland.refreshToplevels(); hyprSettle.restart() }
  }
  Timer { id: hyprSettle; interval: 150; onTriggered: win.hyprRevision++ }
  Component.onCompleted: hyprRefresh.restart()

  // ------------------------------------------------------------ files

  // The widgets that live on this monitor.
  readonly property var files: {
    var all = win.app.files, out = []
    void win.app.layout
    void win.app.arrivals
    for (var i = 0; i < all.length; i++) if (win.app.screenOf(all[i]) === win.name) out.push(all[i])
    return out
  }

  // Where each is: this monitor's saved cells, and those of widgets placed on
  // another monitor that isn't connected, which show here meanwhile and keep
  // their own place for when it is back.
  property var visiting: ({})
  readonly property var saved: win.app.layout.screens[win.name] || ({})
  readonly property var cells: {
    var out = {}
    for (var f in win.saved) out[f] = win.saved[f]
    for (var v in win.visiting) if (win.files.indexOf(v) >= 0) out[v] = win.visiting[v]
    return out
  }

  function isVisitor(file) {
    var s = Layout.savedScreen(win.app.layout, file)
    return s !== "" && s !== win.name
  }

  // Saves `next`, this monitor's cells after a change to `own`, which live
  // here from now on (a visitor that's moved stays).
  function save(next, own) {
    var keep = {}, visiting = {}
    for (var f in next) {
      if (win.isVisitor(f) && (own || []).indexOf(f) < 0) visiting[f] = next[f]
      else keep[f] = next[f]
    }
    win.visiting = visiting
    win.app.saveScreen(win.name, keep, (own || []).filter(function(f) { return !!keep[f] }))
  }

  // New widgets take the first free place once they have compiled and their
  // size is known; a widget that fails to compile gets the default 3x2.
  Timer {
    id: settleLater
    interval: 60
    onTriggered: {
      if (!win.app.ready || win.width <= 0 || win.height <= 0) return
      var sizes = {}
      for (var i = 0; i < tiles.count; i++) {
        var t = tiles.itemAt(i) as Tile
        if (t && (t.owl.program || t.owl.error)) sizes[t.file] = { size: t.owl.size, face: t.owl.isFace }
      }
      var r = Layout.settle(win.cells, win.files, sizes, win.columns, win.rows)
      if (r.placed.length) win.save(r.cells, r.placed.filter(function(f) { return !win.isVisitor(f) }))
      // A face added from the store shows in place of the one showing.
      for (var f in win.app.reveal) {
        if (win.app.reveal[f] !== win.name || !Layout.isFace(win.cells[f])) continue
        if (win.cells[f].hidden) win.showTile(f)
        win.app.revealed(f)
      }
    }
  }
  onFilesChanged: settleLater.restart()
  onColumnsChanged: settleLater.restart()
  onRowsChanged: settleLater.restart()
  Connections {
    target: win.app
    function onReadyChanged() { settleLater.restart() }
    function onRevealChanged() { if (Object.keys(win.app.reveal).length) settleLater.restart() }
  }

  function tileFor(file) {
    for (var i = 0; i < tiles.count; i++) {
      var t = tiles.itemAt(i) as Tile
      if (t && t.file === file) return t
    }
    return null
  }

  function reloadWidgets() {
    for (var i = 0; i < tiles.count; i++) {
      var t = tiles.itemAt(i) as Tile
      if (t) t.owl.load()
    }
  }

  function describe() {
    var out = []
    for (var i = 0; i < tiles.count; i++) {
      var t = tiles.itemAt(i) as Tile
      if (t) out.push({ file: t.file, name: t.owl.name, monitor: win.name, cell: win.cells[t.file] || null, face: t.owl.isFace,
                        running: t.owl.active, error: t.owl.error || null, problems: t.owl.problems })
    }
    return out
  }

  function openScreen(file) {
    var t = win.tileFor(file)
    if (!t || !t.owl.hasScreen) return false
    t.owl.openScreen()
    return true
  }

  // ------------------------------------------------------------ arranging

  readonly property bool editing: win.app.arrangingOn === win.name
  property string selected: ""
  // A tile being dragged or resized: the action bar waits until it's let go.
  property bool holding: false
  onEditingChanged: {
    win.holding = false
    win.selected = win.editing ? win.app.arrangeFile : ""
    if (win.editing) keys.forceActiveFocus()
  }
  onSelectedChanged: win.holding = false

  function arrange(file) {
    if (win.screenWidget) return
    win.app.arrangeFile = file || ""
    if (win.app.arrangingOn === win.name) win.selected = file || ""
    win.app.arrangingOn = win.name
  }
  function finishEditing() {
    win.app.arrangingOn = ""
    win.app.arrangeFile = ""
  }

  function moveTo(file, x, y) {
    var next = Layout.move(win.cells, file, x, y, win.columns, win.rows, win.files)
    if (next) win.save(next, [file])
    return !!next
  }
  function resizeTo(file, w, h) {
    var t = win.tileFor(file)
    var next = Layout.resize(win.cells, file, w, h, t ? t.owl.minSize : [1, 1], win.columns, win.rows, win.files)
    if (next) win.save(next, [file])
    return !!next
  }
  function placeAt(file, cell) {
    var next = Layout.place(win.cells, file, cell, win.columns, win.rows, win.files)
    if (next) win.save(next, [file])
    return !!next
  }
  function hideTile(file) {
    var next = Layout.hide(win.cells, file)
    if (!next) return
    win.save(next, [file])
    win.selected = ""
  }
  function showTile(file) {
    var t = win.tileFor(file)
    var next = Layout.show(win.cells, file, t ? t.owl.size : [3, 2], t && t.owl.isFace, win.columns, win.rows, win.files)
    if (!next) return win.app.say("No room on this screen for " + win.title(file) + ": make room, or resize another widget", true)
    win.save(next, [file])
    win.selected = t && t.owl.isFace ? "" : file
  }

  readonly property var hiddenFiles: win.files.filter(function(f) { return win.cells[f] && win.cells[f].hidden })
  // Widgets with no room left on the screen: they wait in the list beside the hidden ones.
  readonly property var waitingFiles: win.files.filter(function(f) {
    if (win.cells[f]) return false
    var t = win.tileFor(f)
    return !!t && !!(t.owl.program || t.owl.error)
  })

  function title(file) {
    var t = win.tileFor(file)
    if (t && t.owl.program) return t.owl.name
    var parts = file.replace(/\.owl$/, "").split("/")
    return parts[parts.length - 1] === "widget" && parts.length > 1 ? parts[parts.length - 2] : parts[parts.length - 1]
  }

  readonly property string selectedPath: win.selected ? win.app.dir + "/" + win.selected : ""
  readonly property string selectedStoreId: win.selected ? win.app.storeIdFor(win.selected) : ""

  function edit() { if (win.selectedPath) win.app.widgets(["edit", win.selectedPath]) }
  function share() { if (win.selectedPath) win.app.widgets(["share", "--terminal", win.selectedPath]) }
  function uninstall() {
    var id = win.selectedStoreId
    if (!id) return
    win.app.widgets(win.app.storeKindFor(win.selected) === "face" ? ["remove", "--yes", "--faces", id] : ["remove", "--yes", id])
    win.selected = ""
  }

  // Keys while arranging; true when used.
  function key(event) {
    if (!win.editing) return false
    var shift = event.modifiers & Qt.ShiftModifier
    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { win.finishEditing(); return true }
    if (event.key === Qt.Key_Tab) {
      var shown = win.files.filter(function(f) { return win.cells[f] && !win.cells[f].hidden && !Layout.isFace(win.cells[f]) })
      if (shown.length) win.selected = shown[(shown.indexOf(win.selected) + 1) % shown.length]
      return true
    }
    if (!win.selected) return false
    if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) { win.hideTile(win.selected); return true }
    var dx = event.key === Qt.Key_Left ? -1 : event.key === Qt.Key_Right ? 1 : 0
    var dy = event.key === Qt.Key_Up ? -1 : event.key === Qt.Key_Down ? 1 : 0
    if (!dx && !dy) return false
    var c = win.cells[win.selected]
    if (!c || Layout.isFace(c)) return false
    if (shift) win.resizeTo(win.selected, c.w + dx, c.h + dy)
    else win.moveTo(win.selected, c.x + dx, c.y + dy)
    return true
  }

  // ------------------------------------------------------------ screen { }

  // The widget whose screen { } is up, over everything on this monitor.
  property var screenWidget: null
  // What a screen { } has to draw in (ScreenWindow's card, less its frame,
  // padding and title row), for screenWidth and screenHeight.
  readonly property real screenCardWidth: Math.min(win.width - 2 * win.grid.margin, 400 * win.dp)
  readonly property real screenCardHeight: win.height - 2 * win.grid.margin
  readonly property real screenAreaWidth: win.screenCardWidth - 2 * (2 + 12) * win.dp
  readonly property real screenAreaHeight: win.screenCardHeight - 2 * (2 + 12) * win.dp - 46 * win.dp


  // ------------------------------------------------------------ input

  // The pointer goes to the tiles and passes through everywhere else; the
  // whole screen takes it while arranging and while a widget's Popup is open,
  // so a click beside them finishes or dismisses.
  property int popups: 0
  readonly property bool wholeScreen: win.editing || win.popups > 0
  property var tileRegions: []
  function updateRegions() {
    var out = []
    for (var i = 0; i < tiles.count; i++) {
      var t = tiles.itemAt(i) as Tile
      if (t && t.region) out.push(t.region)
    }
    win.tileRegions = out
  }

  mask: Region {
    item: win.wholeScreen ? everything : null
    regions: win.tileRegions
  }

  // A Popup puts its menu over the window: a child of the window's own item,
  // above everything (OwlNode.qml's popupC). Counted as they come and go.
  property var watchedPopups: []
  function countPopups() {
    var n = 0, list = win.contentItem ? win.contentItem.children : [], kids = []
    for (var j = 0; j < list.length; j++) kids.push(list[j])
    var watched = win.watchedPopups.filter(function(k) { return kids.indexOf(k) >= 0 })
    for (var i = 0; i < kids.length; i++) {
      var k = kids[i]
      if (k.z !== 10000) continue
      if (watched.indexOf(k) < 0) {
        watched.push(k)
        k.visibleChanged.connect(win.countPopups)
      }
      if (k.visible) n++
    }
    win.watchedPopups = watched
    win.popups = n
  }
  Connections {
    target: win.contentItem
    function onChildrenChanged() { Qt.callLater(win.countPopups) }
  }

  // ------------------------------------------------------------ the desktop

  Item {
    id: everything
    anchors.fill: parent
  }

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.onPressed: (event) => { if (win.key(event)) event.accepted = true }

    // A click beside the tiles finishes arranging, as a tap outside does on the phone.
    MouseArea {
      anchors.fill: parent
      enabled: win.editing
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: win.finishEditing()
    }

    // The grid's cells while arranging, as the phone shows them.
    Repeater {
      model: win.editing ? win.columns * win.rows : 0
      delegate: Rectangle {
        required property int index
        readonly property var r: win.cellRect({ x: index % win.columns, y: Math.floor(index / win.columns), w: 1, h: 1 })
        x: r.x
        y: r.y
        width: r.width
        height: r.height
        color: "transparent"
        border.width: 1
        border.color: win.app.alpha(win.app.ink("border"), 0.35)
      }
    }

    // Where the tile being dragged would land.
    Rectangle {
      id: ghostRect
      property var cell: null
      property bool fits: false
      readonly property var r: ghostRect.cell ? win.cellRect(ghostRect.cell) : null
      visible: !!ghostRect.cell
      x: ghostRect.r ? ghostRect.r.x : 0
      y: ghostRect.r ? ghostRect.r.y : 0
      width: ghostRect.r ? ghostRect.r.width : 0
      height: ghostRect.r ? ghostRect.r.height : 0
      z: 3
      color: win.app.alpha(ghostRect.fits ? win.app.ink("accent") : win.app.ink("red"), 0.12)
      border.width: Math.max(1, 2 * win.dp)
      border.color: ghostRect.fits ? win.app.ink("accent") : win.app.ink("red")
    }

    // The edge being dragged, right under the pointer: only this outline moves
    // while resizing, and the widget takes its new size on release.
    Rectangle {
      id: outlineRect
      property rect r: Qt.rect(0, 0, 0, 0)
      visible: outlineRect.r.width > 0
      x: outlineRect.r.x
      y: outlineRect.r.y
      width: outlineRect.r.width
      height: outlineRect.r.height
      z: 5
      color: "transparent"
      border.width: Math.max(2, 3 * win.dp)
      border.color: win.app.settingColor(win.style.borderFocused, "accent")
    }

    Repeater {
      id: tiles
      model: win.files
      onItemAdded: Qt.callLater(win.updateRegions)
      onItemRemoved: Qt.callLater(win.updateRegions)

      delegate: Tile {
        desk: win
        app: win.app
        host: win.host
        ghost: ghostRect
        outline: outlineRect
        onSettle: settleLater.restart()
        onRegionChanged: Qt.callLater(win.updateRegions)
      }
    }

    // What the selected tile can do, next to it, as on the phone: above it,
    // or below where there's no room; hidden while it's held.
    Rectangle {
      id: actionBar
      readonly property var t: win.editing && win.selected && !win.holding ? win.tileFor(win.selected) : null
      visible: !!actionBar.t && !actionBar.t.owl.isFace
      z: 6
      width: tileActions.implicitWidth + 12
      height: tileActions.implicitHeight + 12
      x: actionBar.t ? Math.max(0, Math.min(actionBar.t.x, win.width - width)) : 0
      y: actionBar.t ? (actionBar.t.y - height - 6 >= 0 ? actionBar.t.y - height - 6 : actionBar.t.y + actionBar.t.height + 6) : 0
      color: win.app.ink("background")
      border.width: 1
      border.color: win.app.ink("accent")
      MouseArea { anchors.fill: parent }

      Row {
        id: tileActions
        anchors.centerIn: parent
        spacing: 6
        Btn { app: win.app; text: "Edit"; onClicked: win.edit() }
        Btn { app: win.app; text: "Share"; onClicked: win.share() }
        Btn { app: win.app; visible: Quickshell.screens.length > 1; text: "Next screen"; onClicked: { var f = win.selected; win.selected = ""; win.app.moveToNextScreen(f) } }
        Btn { app: win.app; visible: win.selectedStoreId !== ""; text: "Store page"; onClicked: win.app.openStore(win.selectedStoreId, win.app.storeKindFor(win.selected)) }
        Btn { app: win.app; visible: win.selectedStoreId !== ""; text: "Uninstall"; onClicked: win.uninstall() }
        Btn { app: win.app; visible: win.selectedStoreId === ""; text: "Take off"; onClicked: win.hideTile(win.selected) }
      }
    }

    // While arranging: what the desktop can do, and the widgets that are off it.
    Rectangle {
      id: footer
      visible: win.editing
      z: 6
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: win.grid.margin + 6
      width: Math.min(win.width - 2 * win.grid.margin, footerRow.implicitWidth + 24)
      height: footerRow.implicitHeight + 16
      color: win.app.ink("background")
      border.width: Math.max(1, 2 * win.dp)
      border.color: win.app.ink("accent")
      MouseArea { anchors.fill: parent }

      Row {
        id: footerRow
        anchors.centerIn: parent
        spacing: 6
        Btn { app: win.app; text: "Create"; onClicked: win.app.create() }
        Btn { app: win.app; text: "Store"; onClicked: win.app.openStore("", "") }
        Btn { app: win.app; text: "Style"; onClicked: win.app.editStyle() }
        Btn { app: win.app; text: "Folder"; onClicked: Quickshell.execDetached(["xdg-open", win.app.dir]) }
        Repeater {
          model: win.hiddenFiles.concat(win.waitingFiles)
          delegate: Btn {
            required property string modelData
            app: win.app
            text: "+ " + win.title(modelData)
            onClicked: win.showTile(modelData)
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          leftPadding: 6
          rightPadding: 6
          text: "Drag a tile to move it, an edge to resize it. Click beside the tiles when you're done."
          color: win.app.ink("muted")
          font.family: win.app.font
          font.pixelSize: 12
        }
        Btn { app: win.app; primary: true; text: "Done"; onClicked: win.finishEditing() }
      }
    }

    // A line of news: what a command did, or why it didn't.
    Rectangle {
      visible: win.app.message !== "" && win.name === win.app.focusedScreen
      z: 7
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: footer.visible ? footer.top : parent.bottom
      anchors.bottomMargin: win.grid.margin + 6
      width: Math.min(win.width - 2 * win.grid.margin, news.implicitWidth + 24)
      height: news.implicitHeight + 14
      color: win.app.messageIsError ? Qt.tint(win.app.ink("background"), win.app.alpha(win.app.ink("red"), 0.16)) : win.app.ink("background")
      border.width: 1
      border.color: win.app.messageIsError ? win.app.ink("red") : win.app.ink("border")
      Text {
        id: news
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 24)
        text: win.app.message
        color: win.app.messageIsError ? win.app.ink("red") : win.app.ink("foreground")
        font.family: win.app.font
        font.pixelSize: 12
        elide: Text.ElideRight
      }
    }
  }
}
