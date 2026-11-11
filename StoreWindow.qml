pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Store.js" as Store
import "owl/Owl.js" as OwlJs

// The store, as Omalauncher has it (ui/StoreScreen.kt): the reviewed widgets
// and faces of github.com/SimonSchubert/omarchy-widgets in the launcher's
// full-screen panel. A grid of previews with a search and tabs, and beside it
// the picked one's page: what it is, what it installs and runs, and the button
// that adds it, updates it or removes it. Where there's no room for both, the
// page takes the grid's place, its name with a chevron back in the header.
//
// Installing goes through bin/omarchy-widgets with the SHA-256 this page
// showed, so only the reviewed file that was read gets installed.
PanelWindow {
  id: win

  required property var app
  required property var desk
  property real dp: 1

  readonly property string name: win.screen ? String(win.screen.name) : ""
  readonly property bool open: win.app.storeOn !== "" && win.app.storeOn === win.name

  visible: win.open
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "owl-desktop-store"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  exclusionMode: ExclusionMode.Normal
  anchors { top: true; bottom: true; left: true; right: true }

  // The launcher's colors and sizes for its screens (Theme.kt).
  readonly property StoreUi ui: StoreUi {
    dp: win.dp
    corner: win.app.corner
    font: win.app.font
    background: win.app.phone.background
    surface: win.app.phone.surface
    overlay: win.app.phone.overlay
    foreground: win.app.phone.foreground
    muted: win.app.phone.muted
    accent: win.app.phone.accent
    border: win.app.phone.border
    red: win.app.phone.red
    green: win.app.phone.green
  }

  // ------------------------------------------------------------ the catalogs

  property string kind: "widget"
  property var catalogs: ({ widget: [], face: [] })
  property var loading: ({ widget: false, face: false })
  property var loaded: ({ widget: false, face: false })
  property var errors: ({ widget: "", face: "" })
  // Each kind keeps its search and tab while the other shows.
  property var queries: ({ widget: "", face: "" })
  property var tabsOn: ({ widget: "all", face: "all" })

  function setIn(map, key, value) {
    var next = Object.assign({}, win[map])
    next[key] = value
    win[map] = next
  }

  function load(k) {
    if (win.loading[k]) return
    win.setIn("loading", k, true)
    win.setIn("errors", k, "")
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      win.setIn("loading", k, false)
      if (xhr.status !== 200) {
        win.setIn("errors", k, "couldn't load the store: " + (xhr.status ? "HTTP " + xhr.status : "it can't be reached"))
      } else {
        try {
          win.setIn("catalogs", k, Store.parse(xhr.responseText, Store.KINDS[k].key))
          win.setIn("loaded", k, true)
        } catch (e) {
          win.setIn("errors", k, "couldn't load the store: " + e.message)
        }
      }
      win.showPending()
    }
    xhr.open("GET", win.app.storeBase + "/" + Store.KINDS[k].catalog)
    xhr.send()
  }

  readonly property var entries: win.catalogs[win.kind] || []
  readonly property var records: win.kind === "face" ? win.app.faceRecords : win.app.records
  readonly property string noun: Store.KINDS[win.kind].plural
  readonly property string query: win.queries[win.kind]
  readonly property string tab: win.tabsOn[win.kind]
  readonly property var tabList: Store.tabs(win.entries, win.records, OwlJs.LEVEL)
  readonly property var shown: Store.shown(win.entries, win.records, win.tab, win.query)

  // ------------------------------------------------------------ opening

  // The entry whose page is open; side by side, the grid's first until one is picked.
  property string openId: ""
  // An entry asked for by id (owl-desktop store <author/name>), until its catalog is here.
  property string pending: ""

  function find(list, id) {
    for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
    return null
  }
  readonly property bool wide: body.width >= 720 * win.dp
  readonly property var detail: win.find(win.entries, win.openId)
  readonly property var picked: win.wide ? (win.detail || win.shown[0] || null) : win.detail

  onOpenChanged: {
    if (!win.open) { win.confirming = ""; return }
    win.message = ""
    if (win.app.storeKind) win.kind = win.app.storeKind
    win.pending = win.app.storePick
    win.load(win.kind)
    if (win.pending) win.load(win.kind === "face" ? "widget" : "face")
    if (!win.pending) win.openId = ""
    win.showPending()
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function showPending() {
    var id = win.pending
    if (!id) return
    var kinds = win.kind === "face" ? ["face", "widget"] : ["widget", "face"]
    for (var i = 0; i < kinds.length; i++) {
      if (win.find(win.catalogs[kinds[i]], id)) {
        win.pending = ""
        win.kind = kinds[i]
        win.setIn("queries", kinds[i], "")
        win.setIn("tabsOn", kinds[i], "all")
        win.openId = id
        return
      }
    }
    if (win.loaded.widget && win.loaded.face && !win.loading.widget && !win.loading.face) {
      win.pending = ""
      win.message = "the store has no " + id
      win.messageId = ""
    }
  }

  function setKind(k) {
    if (k === win.kind) return
    win.kind = k
    win.openId = ""
    win.message = ""
    win.load(k)
  }

  function pick(e) {
    win.openId = e.id
    win.message = ""
    if (!win.wide) page.contentY = 0
  }

  // Back one step: the dialog, a page on its own, the search, then the store.
  function back() {
    if (win.confirming) win.confirming = ""
    else if (!win.wide && win.detail) win.openId = ""
    else if (win.query) win.setIn("queries", win.kind, "")
    else win.app.closeStore()
  }

  // ------------------------------------------------------------ installing

  property var busy: ({})
  property string message: ""
  property string messageId: ""
  property string confirming: ""
  onConfirmingChanged: {
    if (win.confirming) Qt.callLater(function() { cancel.forceActiveFocus() })
    else if (win.open) search.forceActiveFocus()
  }
  // What each installed file hashes to now: whether updating throws changes away.
  property var shas: ({})

  function recordOf(e) { return e ? win.records[e.id] || null : null }
  // The hash it was installed with: its record's, or, for a starter widget
  // recorded without one, the starter file's of that version.
  function installedSha(e) {
    var r = win.recordOf(e)
    if (!r) return ""
    if (r.sha256) return r.sha256
    var s = win.kind === "widget" ? win.app.starterRecords[e.id] : null
    return s && s.version === r.version && s.file === r.file ? s.sha256 || "" : ""
  }
  function fileOf(e) { return Store.fileFor(e, win.recordOf(e), win.kind) }

  onPickedChanged: {
    page.contentY = 0
    var e = win.picked, r = win.recordOf(e)
    if (!e || !r || !Store.hasUpdate(e, r, OwlJs.LEVEL)) return
    var file = win.fileOf(e)
    win.app.run(["bash", "-c", "[[ -f $1 ]] || exit 3; sha256sum -- \"$1\" | cut -d' ' -f1", "sha", win.app.dir + "/" + file], function(code, out) {
      win.setIn("shas", file, code === 3 ? null : code === 0 ? out.trim() : undefined)
    })
  }

  function storeArgs(verb, e) {
    var args = [verb, "--yes"]
    if (verb === "install") args.push("--sha256=" + e.sha256)
    if (win.kind === "face") args.push("--faces")
    return args.concat([e.id])
  }

  function install(e) {
    if (!e || win.busy[e.id]) return
    var k = win.kind, r = win.recordOf(e), file = win.fileOf(e)
    win.openId = e.id
    win.message = ""
    win.setIn("busy", e.id, r ? "updating…" : "installing…")
    if (!r) win.app.expectArrival(file, win.name)
    win.app.widgets(win.storeArgs("install", e), function(code, out, err) {
      win.setIn("busy", e.id, "")
      if (code !== 0) {
        var why = err.replace(/^omarchy-widgets: /, "").trim()
        win.messageId = e.id
        win.message = /doesn't match the reviewed/.test(why) ? why : "install failed: " + (why || "it exited with " + code)
        if (/changed in the store since you read it/.test(why)) win.load(k)
        return
      }
      win.setIn("shas", file, e.sha256)
      // A widget closes the store to show it on the desktop, as the phone
      // shows it on its page; a face stays, its page saying where it went.
      if (k === "face") win.app.revealFace(file, win.name)
      else win.app.closeStore()
    }, true)
  }

  function remove(e) {
    win.confirming = ""
    if (!e || win.busy[e.id]) return
    win.message = ""
    win.app.widgets(win.storeArgs("remove", e), function(code, out, err) {
      if (code === 0) return
      win.messageId = e.id
      win.message = err.replace(/^omarchy-widgets: /, "").trim() || "couldn't remove it"
    }, true)
  }

  // Your agent, or your editor, and the share sheet: both open windows of
  // their own, which this panel would cover.
  function edit(e) {
    win.app.widgets(["edit", win.app.dir + "/" + win.fileOf(e)])
    win.app.closeStore()
  }
  function share(e) {
    win.app.widgets(["share", "--terminal", win.app.dir + "/" + win.fileOf(e)])
    win.app.closeStore()
  }

  // Where an installed one is on this monitor: "shown", "hidden" (taken off,
  // or a face behind another), or "" (elsewhere, or not placed yet).
  function placeOf(e) {
    var file = win.fileOf(e), c = win.desk.cells[file]
    if (!c || win.app.screenOf(file) !== win.name) return ""
    return c.hidden ? "hidden" : "shown"
  }

  // ------------------------------------------------------------ keys

  FontMetrics { id: smallFont; font.family: win.ui.font; font.pixelSize: win.ui.small }
  FontMetrics { id: bodyFont; font.family: win.ui.font; font.pixelSize: win.ui.body }

  Item {
    id: keys
    anchors.fill: parent
    focus: true

    Keys.onPressed: (event) => {
      var ctrl = event.modifiers & Qt.ControlModifier
      if (event.key === Qt.Key_Escape) win.back()
      else if (ctrl && event.key === Qt.Key_R) win.load(win.kind)
      else if (event.text === "/" && !search.activeFocus) search.forceActiveFocus()
      else return
      event.accepted = true
    }

    // The scrim: a click on it closes the store.
    Rectangle {
      anchors.fill: parent
      color: win.ui.overlay
      MouseArea { anchors.fill: parent; onClicked: win.app.closeStore() }
    }

    // ---------------------------------------------------------- the panel

    Rectangle {
      id: frame
      radius: win.ui.corner
      anchors.fill: parent
      anchors.margins: win.app.style.gapsOut * win.dp
      color: win.ui.background
      border.width: 2 * win.dp
      border.color: win.ui.accent

      MouseArea { anchors.fill: parent }

      Item {
        anchors.fill: parent
        anchors.margins: (2 + 12) * win.dp

        Item {
          id: header
          width: parent.width
          height: Math.max(titleRow.height, closer.height)

          Row {
            id: titleRow
            anchors.left: parent.left
            anchors.right: actions.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * win.dp
            readonly property bool alone: !win.wide && !!win.detail

            Text {
              visible: titleRow.alone
              anchors.verticalCenter: parent.verticalCenter
              text: "‹"
              color: win.ui.accent
              font.family: win.ui.font
              font.pixelSize: win.ui.title
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.openId = "" }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, titleRow.width - 30 * win.dp)
              text: titleRow.alone ? win.detail.name : "store"
              color: win.ui.accent
              font.family: win.ui.font
              font.pixelSize: win.ui.title
              elide: Text.ElideRight
              MouseArea { anchors.fill: parent; enabled: titleRow.alone; cursorShape: Qt.PointingHandCursor; onClicked: win.openId = "" }
            }
          }

          Row {
            id: actions
            anchors.right: closer.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4 * win.dp
            visible: !titleRow.alone

            // Widgets or faces: segments, the shown one filled.
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: kinds.width + 2 * border.width
              height: kinds.height + 2 * border.width
              color: "transparent"
              radius: win.ui.corner
              border.width: 1 * win.dp
              border.color: win.ui.border
              Row {
                id: kinds
                x: parent.border.width
                y: parent.border.width
                Repeater {
                  model: ["widget", "face"]
                  delegate: Rectangle {
                    id: segment
                    radius: win.ui.corner
                    required property string modelData
                    readonly property bool on: segment.modelData === win.kind
                    width: label.implicitWidth + 24 * win.dp
                    height: label.implicitHeight + 12 * win.dp
                    color: segment.on ? win.ui.selected : "transparent"
                    Text {
                      id: label
                      anchors.centerIn: parent
                      text: Store.KINDS[segment.modelData].plural
                      color: segment.on ? win.ui.accent : win.ui.muted
                      font.family: win.ui.font
                      font.pixelSize: win.ui.small
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.setKind(segment.modelData) }
                  }
                }
              }
            }

            // Reload: it turns in the accent while it loads.
            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: 32 * win.dp
              height: 32 * win.dp
              Text {
                id: refresh
                anchors.centerIn: parent
                text: "󰑐"
                color: win.loading[win.kind] ? win.ui.accent : win.ui.muted
                font.family: win.ui.font
                font.pixelSize: 20 * win.dp
                RotationAnimator on rotation {
                  running: win.open && !!win.loading[win.kind]
                  from: 0; to: 360; duration: 900; loops: Animation.Infinite
                  onRunningChanged: if (!running) refresh.rotation = 0
                }
              }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.load(win.kind) }
            }
          }

          // nf-md-close, in red, as the launcher's panels close.
          Text {
            id: closer
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            padding: 8 * win.dp
            rightPadding: 0
            text: "󰅖"
            color: win.ui.red
            font.family: win.ui.font
            font.pixelSize: win.ui.title
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.app.closeStore() }
          }
        }

        Item {
          id: body
          anchors.top: header.bottom
          anchors.topMargin: 8 * win.dp
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom

          readonly property real paneWidth: Math.max(340 * win.dp, Math.min(520 * win.dp, body.width * 0.42))

          // -------------------------------------------------------- the grid

          Item {
            id: list
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: win.wide ? body.width - body.paneWidth - 25 * win.dp : body.width
            visible: win.wide || !win.detail

            Rectangle {
              id: searchBox
              radius: win.ui.corner
              width: parent.width
              height: search.implicitHeight + 24 * win.dp
              color: win.ui.surface

              TextInput {
                id: search
                anchors.fill: parent
                anchors.leftMargin: 18 * win.dp
                anchors.rightMargin: 18 * win.dp
                verticalAlignment: TextInput.AlignVCenter
                text: win.query
                onTextEdited: win.setIn("queries", win.kind, text)
                color: win.ui.foreground
                selectionColor: win.ui.accent
                selectedTextColor: win.ui.background
                font.family: win.ui.font
                font.pixelSize: win.ui.item
                clip: true
                activeFocusOnTab: true
                // Enter or Down: into the grid.
                Keys.onReturnPressed: grid.focusFirst()
                Keys.onEnterPressed: grid.focusFirst()
                Keys.onDownPressed: grid.focusFirst()
              }
              Text {
                anchors.fill: search
                verticalAlignment: Text.AlignVCenter
                visible: !search.text
                text: "search " + win.entries.length + " " + win.noun
                color: win.ui.muted
                font.family: win.ui.font
                font.pixelSize: win.ui.item
              }
            }

            ListView {
              id: chips
              anchors.top: searchBox.bottom
              anchors.topMargin: 8 * win.dp
              width: parent.width
              height: smallFont.height + 14 * win.dp
              orientation: ListView.Horizontal
              spacing: 6 * win.dp
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              model: win.tabList
              delegate: Rectangle {
                id: chip
                radius: win.ui.corner
                required property var modelData
                readonly property bool on: chip.modelData.name === win.tab
                width: chipLabel.implicitWidth + 24 * win.dp
                height: chips.height
                color: chip.on ? win.ui.selected : chipMouse.containsMouse ? win.app.alpha(win.ui.foreground, 0.06) : "transparent"
                border.width: 1 * win.dp
                border.color: chip.on ? win.ui.accent : win.ui.border
                Text {
                  id: chipLabel
                  anchors.centerIn: parent
                  text: Store.tabLabel(chip.modelData)
                  color: chip.on ? win.ui.accent : win.ui.foreground
                  font.family: win.ui.font
                  font.pixelSize: win.ui.small
                }
                MouseArea {
                  id: chipMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { win.setIn("tabsOn", win.kind, chip.modelData.name); grid.positionViewAtBeginning() }
                }
              }
            }

            GridView {
              id: grid
              anchors.top: chips.bottom
              anchors.topMargin: 10 * win.dp
              anchors.bottom: parent.bottom
              // A gap wider than the list, so the last column's gap falls past its edge.
              width: parent.width + gap
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              keyNavigationEnabled: true
              activeFocusOnTab: true
              currentIndex: -1
              readonly property real gap: 8 * win.dp
              readonly property int perRow: Math.max(1, Math.floor(width / (150 * win.dp + gap)))
              cellWidth: Math.floor(width / perRow)
              cellHeight: (8 + 104 + 4 + 4 + 8) * win.dp + bodyFont.height + smallFont.height + 6 * win.dp + gap
              model: win.shown

              function focusFirst() {
                if (!win.shown.length) return
                grid.forceActiveFocus()
                if (grid.currentIndex < 0) grid.currentIndex = 0
                win.pick(win.shown[grid.currentIndex])
              }
              onCurrentIndexChanged: if (activeFocus && currentIndex >= 0 && currentIndex < win.shown.length) win.pick(win.shown[currentIndex])
              Keys.onReturnPressed: if (!win.wide && win.picked) page.forceActiveFocus()
              Keys.onUpPressed: (event) => {
                if (grid.currentIndex < grid.perRow) search.forceActiveFocus()
                else event.accepted = false
              }

              header: Column {
                width: grid.width - grid.gap
                spacing: 8 * win.dp
                bottomPadding: 8 * win.dp
                Text {
                  width: parent.width
                  text: "reviewed " + win.noun + " from github.com/" + Store.REPO
                  color: win.ui.muted
                  font.family: win.ui.font
                  font.pixelSize: win.ui.small
                  elide: Text.ElideRight
                }
                Text {
                  readonly property string error: win.errors[win.kind]
                  width: parent.width
                  visible: text !== ""
                  wrapMode: Text.Wrap
                  text: win.loading[win.kind] && !win.entries.length ? "loading…"
                    : error && !win.entries.length ? error
                    : !win.entries.length && win.loaded[win.kind] ? "no " + win.noun + " yet"
                    : win.shown.length || !win.entries.length ? ""
                    : win.query.trim() ? "nothing matches \"" + win.query.trim() + "\""
                    : win.tab === "new" ? "no new " + win.noun
                    : win.tab === "installed" ? "no " + win.noun + " installed from the store"
                    : ""
                  color: error && !win.entries.length ? win.ui.red : win.ui.muted
                  font.family: win.ui.font
                  font.pixelSize: win.ui.body
                }
              }

              delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property var record: win.records[cell.modelData.id] || null
                readonly property var status: Store.cardStatus(cell.modelData, cell.record, OwlJs.LEVEL, win.busy[cell.modelData.id] || "")
                readonly property bool on: win.wide && !!win.picked && win.picked.id === cell.modelData.id
                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                  id: card
                  radius: win.ui.corner
                  width: cell.width - grid.gap
                  height: cell.height - grid.gap
                  color: cardMouse.containsMouse ? win.app.alpha(win.ui.foreground, 0.04) : "transparent"
                  border.width: 1 * win.dp
                  border.color: cell.on || (grid.activeFocus && grid.currentIndex === cell.index) ? win.ui.accent : win.ui.border

                  Item {
                    id: shot
                    x: 8 * win.dp
                    y: 8 * win.dp
                    width: card.width - 16 * win.dp
                    height: 104 * win.dp
                    clip: true

                    Rectangle {
                      anchors.fill: parent
                      visible: thumb.status !== Image.Ready
                      radius: win.ui.corner
                      color: win.ui.surface
                      Text {
                        anchors.centerIn: parent
                        width: parent.width - 8 * win.dp
                        horizontalAlignment: Text.AlignHCenter
                        text: cell.modelData.name
                        color: win.ui.muted
                        font.family: win.ui.font
                        font.pixelSize: win.ui.small
                        elide: Text.ElideRight
                      }
                    }
                    // A widget whole; a face, a whole screen, by its top as wide as the card.
                    Image {
                      id: thumb
                      anchors.fill: parent
                      readonly property string path: Store.preview(cell.modelData, win.app.themeName)
                      source: path ? win.app.storeBase + "/" + path : ""
                      fillMode: win.kind === "face" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                      verticalAlignment: win.kind === "face" ? Image.AlignTop : Image.AlignVCenter
                      sourceSize.height: win.kind === "face" ? 0 : 2 * height
                      sourceSize.width: win.kind === "face" ? 2 * width : 0
                      asynchronous: true
                      cache: true
                      smooth: true
                    }
                  }

                  Row {
                    id: nameRow
                    anchors.top: shot.bottom
                    anchors.topMargin: 4 * win.dp
                    x: 8 * win.dp
                    width: card.width - 16 * win.dp
                    spacing: 6 * win.dp
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.min(implicitWidth, nameRow.width - (badge.visible ? badge.width + nameRow.spacing : 0))
                      text: cell.modelData.name
                      color: win.ui.foreground
                      font.family: win.ui.font
                      font.pixelSize: win.ui.body
                      elide: Text.ElideRight
                    }
                    NewBadge { id: badge; ui: win.ui; visible: !!cell.modelData.new; anchors.verticalCenter: parent.verticalCenter }
                  }
                  Text {
                    anchors.top: nameRow.bottom
                    anchors.topMargin: 4 * win.dp
                    x: 8 * win.dp
                    width: card.width - 16 * win.dp
                    text: cell.status.text
                    color: win.ui.color(cell.status.color)
                    font.family: win.ui.font
                    font.pixelSize: win.ui.small
                    elide: Text.ElideRight
                  }

                  MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { grid.currentIndex = cell.index; win.pick(cell.modelData) }
                  }
                }
              }
            }
          }

          Rectangle {
            visible: win.wide
            x: list.width + 12 * win.dp
            width: 1 * win.dp
            height: body.height
            color: win.ui.border
          }

          // -------------------------------------------------------- a page

          Text {
            visible: win.wide && !win.picked
            anchors.centerIn: page
            text: "pick a " + Store.KINDS[win.kind].one + " to see what it installs and runs"
            color: win.ui.muted
            font.family: win.ui.font
            font.pixelSize: win.ui.small
          }

          Flickable {
            id: page
            visible: !!win.picked
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: win.wide ? body.paneWidth : Math.min(body.width, 640 * win.dp)
            anchors.rightMargin: win.wide ? 0 : (body.width - width) / 2
            contentHeight: pageColumn.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Keys.onUpPressed: page.flick(0, 800)
            Keys.onDownPressed: page.flick(0, -800)

            readonly property var e: win.picked || ({ id: "", name: "", commands: [], requires: {} })
            readonly property var record: win.recordOf(win.picked)
            readonly property string file: win.picked ? win.fileOf(win.picked) : ""
            readonly property string busy: win.busy[page.e.id] || ""
            readonly property bool supported: Store.supported(page.e, OwlJs.LEVEL)
            readonly property bool update: Store.hasUpdate(page.e, page.record, OwlJs.LEVEL)
            readonly property string edited: Store.edited(page.record ? { sha256: win.installedSha(page.e) } : null, win.shas[page.file])
            readonly property string place: page.record ? win.placeOf(page.e) : ""

            Column {
              id: pageColumn
              width: page.width
              spacing: 6 * win.dp

              // As wide as the page, but no taller than 320 dp, so a tall one
              // doesn't push its description out of sight.
              Item {
                width: parent.width
                readonly property real ratio: big.implicitHeight > 0 ? big.implicitWidth / big.implicitHeight : 0
                height: ratio > 0 ? Math.min(width, 320 * win.dp * ratio) / ratio : big.path !== "" ? 160 * win.dp : 0
                Rectangle {
                  anchors.fill: parent
                  visible: big.status !== Image.Ready
                  radius: win.ui.corner
                  color: win.ui.surface
                }
                Image {
                  id: big
                  anchors.horizontalCenter: parent.horizontalCenter
                  width: parent.ratio > 0 ? Math.min(parent.width, 320 * win.dp * parent.ratio) : parent.width
                  height: parent.height
                  readonly property string path: win.picked ? Store.preview(win.picked, win.app.themeName) : ""
                  source: path ? win.app.storeBase + "/" + path : ""
                  fillMode: Image.PreserveAspectFit
                  asynchronous: true
                  cache: true
                  smooth: true
                }
              }

              Item { width: 1; height: 4 * win.dp }

              Row {
                width: parent.width
                spacing: 8 * win.dp
                Text {
                  id: pageName
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.min(implicitWidth, parent.width - (pageBadge.visible ? pageBadge.width + 8 * win.dp : 0))
                  text: page.e.name
                  color: win.ui.foreground
                  font.family: win.ui.font
                  font.pixelSize: win.ui.title
                  wrapMode: Text.Wrap
                }
                NewBadge { id: pageBadge; ui: win.ui; visible: !!page.e.new; anchors.verticalCenter: parent.verticalCenter }
              }
              Text {
                width: parent.width
                text: win.picked ? Store.details(page.e) : ""
                color: win.ui.muted
                font.family: win.ui.font
                font.pixelSize: win.ui.small
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                text: page.e.description || ""
                color: win.ui.foreground
                font.family: win.ui.font
                font.pixelSize: win.ui.body
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
              }

              Item { width: 1; height: 4 * win.dp }

              // What it does now: busy, can't, update, where it is, or add it.
              Text {
                visible: !!page.busy
                text: page.busy
                color: win.ui.accent
                font.family: win.ui.font
                font.pixelSize: win.ui.body
              }
              Text {
                visible: !page.busy && !page.supported
                width: parent.width
                text: "needs a newer runtime (owl " + (page.e.owl || 1) + "); owl-desktop update brings one when there is"
                color: win.ui.red
                font.family: win.ui.font
                font.pixelSize: win.ui.small
                wrapMode: Text.Wrap
              }
              Text {
                visible: !page.busy && page.update && page.edited !== ""
                width: parent.width
                text: page.edited === "changed" ? "you changed it, and updating replaces your changes" : "it may have your changes, and updating replaces them"
                color: win.ui.red
                font.family: win.ui.font
                font.pixelSize: win.ui.small
                wrapMode: Text.Wrap
              }
              Bracket {
                ui: win.ui
                visible: !page.busy && page.update
                label: (page.edited !== "" ? "update anyway " : "update ") + (page.record ? page.record.version : "") + " → " + page.e.version
                tint: win.ui.accent
                onClicked: win.install(win.picked)
              }
              Bracket {
                ui: win.ui
                visible: !page.busy && page.supported && !page.record
                label: win.kind === "face" ? "add as a face" : "add to your desktop"
                tint: win.ui.accent
                onClicked: win.install(win.picked)
              }
              // Installed and current: where it went, or the way back there.
              Row {
                visible: !page.busy && !!page.record && !page.update
                spacing: 8 * win.dp
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: page.place !== "hidden"
                  text: win.kind === "face" ? (page.place === "shown" ? "✓ behind your widgets" : "✓ in your widgets folder") : "✓ on your desktop"
                  color: win.ui.green
                  font.family: win.ui.font
                  font.pixelSize: win.ui.body
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: page.place === "hidden" && win.kind !== "face"
                  text: "taken off your desktop"
                  color: win.ui.muted
                  font.family: win.ui.font
                  font.pixelSize: win.ui.body
                }
                Bracket {
                  ui: win.ui
                  anchors.verticalCenter: parent.verticalCenter
                  visible: win.kind === "face" ? page.place !== "shown" : page.place === "hidden"
                  label: win.kind === "face" ? "show it here" : "put it back"
                  tint: win.ui.accent
                  onClicked: {
                    if (win.kind === "face") win.app.revealFace(page.file, win.name)
                    else win.desk.showTile(page.file)
                  }
                }
              }
              // Installed: change it, share it, or take it away (asked first).
              Row {
                visible: !page.busy && !!page.record
                spacing: 0
                Bracket { ui: win.ui; label: "edit"; tint: win.ui.foreground; onClicked: win.edit(win.picked) }
                Bracket { ui: win.ui; label: "share"; tint: win.ui.foreground; onClicked: win.share(win.picked) }
                Bracket { ui: win.ui; label: "remove"; tint: win.ui.red; onClicked: win.confirming = page.e.id }
              }
              Text {
                visible: win.message !== "" && (win.messageId === "" || win.messageId === page.e.id)
                width: parent.width
                text: win.message
                color: win.ui.red
                font.family: win.ui.font
                font.pixelSize: win.ui.small
                wrapMode: Text.Wrap
              }

              Item { width: 1; height: 4 * win.dp }

              // What it installs and runs, before it's added.
              Text {
                width: parent.width
                text: "installs packages: " + Store.packages(page.e.requires)
                color: win.ui.foreground
                font.family: win.ui.font
                font.pixelSize: win.ui.small
                wrapMode: Text.Wrap
              }
              Text {
                visible: Store.changedSinceApproval(page.e, page.record)
                width: parent.width
                text: "its commands or packages changed since the version you approved"
                color: win.ui.red
                font.family: win.ui.font
                font.pixelSize: win.ui.small
                wrapMode: Text.Wrap
              }
              Text {
                width: parent.width
                text: (page.e.commands || []).length ? "runs these commands in Arch:" : "runs no commands"
                color: win.ui.foreground
                font.family: win.ui.font
                font.pixelSize: win.ui.small
              }
              Repeater {
                model: page.e.commands || []
                delegate: Rectangle {
                  id: code
                  radius: win.ui.corner
                  required property string modelData
                  width: pageColumn.width
                  height: codeText.implicitHeight + 12 * win.dp
                  color: win.ui.surface
                  Text {
                    id: codeText
                    x: 6 * win.dp
                    y: 6 * win.dp
                    width: parent.width - 12 * win.dp
                    text: code.modelData.replace(/\s+$/, "")
                    color: win.ui.foreground
                    font.family: win.ui.font
                    font.pixelSize: win.ui.small
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                  }
                }
              }
              Item { width: 1; height: 12 * win.dp }
            }
          }
        }
      }
    }

    // ---------------------------------------------------------- remove?

    Rectangle {
      anchors.fill: parent
      visible: win.confirming !== ""
      color: Qt.rgba(0, 0, 0, 0.6)
      MouseArea { anchors.fill: parent; onClicked: win.confirming = "" }

      Rectangle {
        id: dialog
        radius: win.ui.corner
        anchors.centerIn: parent
        width: Math.min(parent.width - 48 * win.dp, 480 * win.dp)
        height: dialogColumn.height + 40 * win.dp
        color: win.ui.surface
        border.width: 2 * win.dp
        border.color: win.ui.accent
        readonly property var e: win.find(win.entries, win.confirming)
        MouseArea { anchors.fill: parent }

        Column {
          id: dialogColumn
          x: 20 * win.dp
          y: 20 * win.dp
          width: dialog.width - 40 * win.dp
          spacing: 12 * win.dp
          Text {
            width: parent.width
            text: "remove " + (dialog.e ? dialog.e.name : "") + "?"
            color: win.ui.foreground
            font.family: win.ui.font
            font.pixelSize: win.ui.title
            wrapMode: Text.Wrap
          }
          Text {
            width: parent.width
            text: "Its file goes to .removed/ in the widgets folder."
            color: win.ui.muted
            font.family: win.ui.font
            font.pixelSize: win.ui.body
            wrapMode: Text.Wrap
          }
          Row {
            anchors.right: parent.right
            Bracket { id: cancel; ui: win.ui; label: "cancel"; tint: win.ui.muted; onClicked: win.confirming = "" }
            Bracket { ui: win.ui; label: "remove"; tint: win.ui.red; onClicked: win.remove(dialog.e) }
          }
        }
      }
    }
  }

  // ------------------------------------------------------------ parts

  // A terminal-style `[ label ]` button.
  component Bracket: Rectangle {
    id: bracket
    radius: bracket.ui.corner
    required property StoreUi ui
    property string label: ""
    property color tint: bracket.ui.accent
    signal clicked()
    implicitWidth: bracketText.implicitWidth + 16 * bracket.ui.dp
    implicitHeight: bracketText.implicitHeight + 12 * bracket.ui.dp
    color: bracketMouse.containsMouse || bracket.activeFocus ? Qt.rgba(bracket.tint.r, bracket.tint.g, bracket.tint.b, 0.1) : "transparent"
    border.width: bracket.activeFocus ? 1 * bracket.ui.dp : 0
    border.color: bracket.tint
    // Keys reach it with Tab, and Enter or Space press it.
    activeFocusOnTab: bracket.visible && bracket.enabled
    Keys.onReturnPressed: bracket.clicked()
    Keys.onEnterPressed: bracket.clicked()
    Keys.onSpacePressed: bracket.clicked()
    Text {
      id: bracketText
      anchors.centerIn: parent
      text: "[ " + bracket.label + " ]"
      color: bracket.tint
      font.family: bracket.ui.font
      font.pixelSize: bracket.ui.body
    }
    MouseArea {
      id: bracketMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: bracket.clicked()
    }
  }

  // Beside the name of one added to the store in the last few days.
  component NewBadge: Rectangle {
    id: newBadge
    radius: newBadge.ui.corner
    required property StoreUi ui
    width: newText.implicitWidth + 10 * newBadge.ui.dp + 2 * border.width
    height: newText.implicitHeight + 2 * newBadge.ui.dp + 2 * border.width
    color: newBadge.ui.selected
    border.width: 1 * newBadge.ui.dp
    border.color: newBadge.ui.accent
    Text {
      id: newText
      anchors.centerIn: parent
      text: "new"
      color: newBadge.ui.accent
      font.family: newBadge.ui.font
      font.pixelSize: newBadge.ui.small
    }
  }
}
