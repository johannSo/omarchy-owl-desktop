//@ pragma Env QS_NO_RELOAD_POPUP=1

// OWL widgets on the desktop: every .owl file in the widget folder, live, on
// Omalauncher's home-screen grid, over the wallpaper and under the windows,
// drawn by the OWL runtime Omalauncher's author keeps for Quickshell (owl/).
//
//   quickshell -p ~/Work/Omarchy/widgets          (owl-desktop start does this)
//
// One layer surface per monitor (DesktopWindow.qml) holds its widgets. Where
// each sits is ~/.local/state/owl-desktop/layout.json; how they look is
// ~/.config/owl-desktop/style.toml; what they persist is beside the layout.

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "owl" as Owl
import "owl/Owl.js" as OwlJs
import "Layout.js" as Layout
import "Style.js" as StyleJs

ShellRoot {
  id: shell

  // ------------------------------------------------------------ places

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || shell.home + "/.config"
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || shell.home + "/.local/state"
  readonly property string configDir: shell.configHome + "/owl-desktop"
  readonly property string stateDir: shell.stateHome + "/owl-desktop"
  readonly property string appDir: shell.localPath(Qt.resolvedUrl("."))
  readonly property string bin: shell.appDir + "/bin/omarchy-widgets"
  readonly property string storeUrl: "https://github.com/SimonSchubert/omarchy-widgets"
  // Where the store's CI publishes its catalogs and reviewed files.
  readonly property string storeBase: (Quickshell.env("OMARCHY_WIDGETS_STORE") || "https://simonschubert.github.io/omarchy-widgets").replace(/\/+$/, "")
  readonly property string dir: {
    var d = Quickshell.env("OWL_WIDGETS") || shell.style.folder || "~/.config/omarchy-widgets"
    if (d === "~" || d.indexOf("~/") === 0) d = shell.home + d.slice(1)
    return d.replace(/\/+$/, "")
  }

  function localPath(url) {
    var u = String(url)
    u = u.indexOf("file://") === 0 ? decodeURIComponent(u.slice(7)) : u
    return u.replace(/\/+$/, "")
  }
  function tilde(path) { return shell.home && path.indexOf(shell.home) === 0 ? "~" + path.slice(shell.home.length) : path }

  // ------------------------------------------------------------ style

  property var style: StyleJs.DEFAULTS
  property var styleProblems: []

  FileView {
    id: styleFile
    path: shell.configDir + "/style.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var r = StyleJs.parse(text())
      shell.style = r.style
      shell.styleProblems = r.problems
      for (var i = 0; i < r.problems.length; i++) console.warn("owl-desktop: " + r.problems[i])
    }
    onLoadFailed: {
      shell.style = StyleJs.DEFAULTS
      // A first start writes the file with every setting and its default, to edit.
      shell.run(["bash", "-c", "mkdir -p \"$1\" && [ -e \"$2\" ] || printf '%s' \"$3\" > \"$2\"", "style", shell.configDir, styleFile.path, StyleJs.TEMPLATE],
                function() { styleFile.reload() })
    }
  }

  // ------------------------------------------------------------ theme

  // OWL's names for the Omarchy palette, read straight from the theme as the
  // launcher reads it; Tokyo Night's until it has loaded.
  property var palette: OwlJs.themeFromToml("")

  FileView {
    path: shell.stateHome + "/omarchy/current/theme/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: { reload(); fontProc.running = true }
    onLoaded: {
      shell.palette = OwlJs.themeFromToml(text())
      var named = {}
      text().split("\n").forEach(function(line) {
        var m = /^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/.exec(line)
        if (m) named[m[1]] = m[2]
      })
      shell.themeNamed = named
    }
  }

  // The theme's colors by colors.toml's names, and the launcher's own palette
  // for its screens made of them (Theme.kt's ThemePalette): the store's.
  property var themeNamed: ({})
  readonly property var phone: {
    var n = shell.themeNamed
    var c = function(k, f) { return Qt.color(n[k] || f) }
    var bg = c("background", "#1a1b26"), surface = c("lighter_background", "#24283b"), fg = c("foreground", "#c0caf5")
    var muted = c("dark_foreground", "#565f89")
    // Subtitles sit on the surface: a theme whose dark_foreground is its
    // lighter_background gets one between the foreground and the background.
    if (shell.contrast(muted, surface) < 1.2) muted = Qt.rgba((fg.r + bg.r) / 2, (fg.g + bg.g) / 2, (fg.b + bg.b) / 2, 1)
    return {
      background: bg, surface: surface, foreground: fg, muted: muted, overlay: Qt.rgba(bg.r, bg.g, bg.b, 0.9),
      accent: c("accent", "#7aa2f7"), border: c("muted", "#414868"), red: c("red", "#f7768e"), green: c("green", "#9ece6a")
    }
  }
  function contrast(a, b) {
    var lum = function(q) {
      var ch = function(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
      return 0.2126 * ch(q.r) + 0.7152 * ch(q.g) + 0.0722 * ch(q.b)
    }
    var x = lum(a), y = lum(b)
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
  }

  // The theme's name, for the store's previews drawn in it.
  property string themeName: ""
  FileView {
    path: shell.stateHome + "/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: shell.themeName = text().trim()
  }

  function ink(name) {
    var v = shell.palette[name]
    return v === undefined || v === null ? "#ff888888" : OwlJs.hex8(v)
  }
  function alpha(c, a) {
    var q = Qt.color(c)
    return Qt.rgba(q.r, q.g, q.b, q.a * a)
  }
  // A color setting: "theme" is `theme`, else a theme color by name or #rrggbb.
  function settingColor(spec, theme) {
    if (!spec || spec === "theme") return shell.ink(theme)
    if (spec[0] === "#") return spec
    return shell.palette[spec] !== undefined ? shell.ink(spec) : shell.ink(theme)
  }

  // Omarchy's font (`omarchy font set`), which the launcher's text and widgets
  // are drawn in; a Nerd Font, so it has weatherIcon()'s glyphs too.
  property string font: "monospace"
  Process {
    id: fontProc
    running: true
    command: ["bash", "-c", "command -v omarchy-font-current >/dev/null && omarchy-font-current || fc-match -f '%{family[0]}' monospace"]
    stdout: StdioCollector {
      onStreamFinished: {
        var f = text.trim().split("\n")[0]
        if (f && f !== shell.font) shell.font = f
      }
    }
  }

  // ------------------------------------------------------------ host

  Owl.OwlHost {
    id: owlHost
    monoFamily: shell.font
    iconFamily: shell.font
    stateDir: shell.stateDir
    launcherVersion: "owl-desktop-1.0.0"
    frameRate: shell.style.frameRate
    gapsIn: shell.style.gapsIn
    gapsOut: shell.style.gapsOut
    borderWidth: shell.style.borderWidth
    tileOpacity: shell.style.opacity
    tileFrost: 0

    function act(widget, name, args) {
      var a = args || []
      function s(i) { return a[i] === undefined || a[i] === null ? "" : String(a[i]) }
      switch (name) {
      case "terminal":
        // Omarchy's terminal when there is one, any other otherwise.
        return Quickshell.execDetached(["bash", "-c",
          "if command -v omarchy-launch-tui >/dev/null; then exec omarchy-launch-tui --app-id=org.omarchy.widgets bash -c \"$1; exec bash\"; " +
          "else exec xdg-terminal-exec bash -c \"$1; exec bash\"; fi", "terminal", s(0)])
      case "app":
        return Quickshell.execDetached(["bash", "-c", "if command -v uwsm-app >/dev/null; then exec uwsm-app -- bash -c \"$1\"; else exec bash -c \"$1\"; fi", "app", s(0)])
      // The phone's default agent, answering in a terminal: Omarchy's.
      case "ask":
        return Quickshell.execDetached(["bash", "-c", "command -v omarchy-agent >/dev/null || exit 1; cd \"$2\" 2>/dev/null; exec omarchy-agent --pick --prompt \"$1\"", "ask", s(0), shell.home])
      case "launcher":
        var route = { themes: "theme", drawer: "apps", agents: "setup.default.agent" }[s(0)]
        if (route) return Quickshell.execDetached(["bash", "-c", "command -v omarchy-menu >/dev/null && exec omarchy-menu summon \"$1\"", "launcher", route])
        if (s(0) === "style" || s(0) === "settings") return shell.editStyle()
        if (s(0) === "store") return shell.openStore("", "")
        if (s(0).indexOf("page:") === 0) return
        return widget.report("launcher(\"" + s(0) + "\") opens a screen of the Android launcher's that the desktop has no counterpart for")
      }
      owlHost.defaultAct(widget, name, a)
    }

    // What's playing, through MPRIS itself: the player the media source reads.
    function mediaAction(op) {
      var players = Mpris.players ? Mpris.players.values : [], p = null
      for (var i = 0; i < players.length; i++) if (players[i].isPlaying) { p = players[i]; break }
      if (!p && players.length) p = players[0]
      if (!p) return
      if (op === "toggle" && p.canTogglePlaying) p.togglePlaying()
      else if (op === "play" && p.canPlay) p.play()
      else if (op === "pause" && p.canPause) p.pause()
      else if (op === "next" && p.canGoNext) p.next()
      else if (op === "previous" && p.canGoPrevious) p.previous()
      else if (op === "open" && p.canRaise) p.raise()
    }

    // Do Not Disturb is the Omarchy shell's, as Omarchy's own toggle switches it.
    function dnd(v) {
      var on = v === "true" || v === "on" || v === "priority" || v === "alarms" || v === "none"
      var off = v === "false" || v === "off" || v === "all"
      var call = v === "toggle" ? "toggleDnd" : on ? "setDnd on" : off ? "setDnd off" : ""
      if (!call) return
      Quickshell.execDetached(["bash", "-c", "omarchy-shell notifications " + call + " >/dev/null 2>&1; omarchy-shell -q omarchy.indicators refresh >/dev/null 2>&1"])
    }
  }

  function editStyle() {
    Quickshell.execDetached(["bash", "-c", "if command -v omarchy-launch-editor >/dev/null; then exec omarchy-launch-editor \"$1\"; else exec xdg-open \"$1\"; fi", "edit", styleFile.path])
  }

  // ------------------------------------------------------------ files

  // Every *.owl in the folder, a level or two down as well, so a checkout of
  // the store (widgets/<author>/<name>/widget.owl) works as it is.
  property var files: []
  property bool scanned: false

  function rescan() { if (!scan.running) scan.running = true; else rescanLater.restart() }

  Process {
    id: scan
    command: ["bash", "-c", "mkdir -p \"$1\" && cd \"$1\" && find -L . -maxdepth 3 -name '*.owl' -not -path '*/.*' | sed 's|^\\./||' | sort", "scan", shell.dir]
    stdout: StdioCollector {
      onStreamFinished: {
        var next = text.split("\n").filter(function(l) { return l !== "" })
        if (JSON.stringify(next) !== JSON.stringify(shell.files)) shell.files = next
        shell.scanned = true
      }
    }
  }
  onDirChanged: { shell.files = []; shell.rescan(); watcher.running = false; watcher.running = true }

  Timer { id: rescanLater; interval: 150; onTriggered: shell.rescan() }

  // A file saved, added or removed shows within a second, as on the phone.
  // inotifywait (inotify-tools) when it's there; a look every two seconds when not.
  property bool watching: false
  Process {
    id: watcher
    running: true
    command: ["bash", "-c", "mkdir -p \"$1\" && command -v inotifywait >/dev/null || exit 127; " +
      "exec inotifywait -m -r -q -e create,delete,moved_to,moved_from --exclude '/\\.[^/]*(/|$)' --format '%e %w%f' \"$1\"", "watch", shell.dir]
    stdout: SplitParser {
      onRead: (line) => {
        shell.watching = true
        if (/\.owl$/.test(line) || /ISDIR/.test(line)) rescanLater.restart()
      }
    }
    onStarted: shell.watching = true
    onExited: (code) => { shell.watching = false; if (code !== 127) restartWatch.restart() }
  }
  Timer { id: restartWatch; interval: 5000; onTriggered: watcher.running = true }
  Timer { interval: 2000; repeat: true; running: !shell.watching; onTriggered: shell.rescan() }

  // ------------------------------------------------------------ layout

  property var layout: Layout.emptyLayout()
  property bool layoutRead: false
  readonly property string layoutPath: shell.stateDir + "/layout.json"

  Process {
    running: true
    command: ["mkdir", "-p", shell.stateDir]
    onExited: layoutFile.path = shell.layoutPath
  }

  FileView {
    id: layoutFile
    printErrors: false
    atomicWrites: true
    onLoaded: {
      var value = null
      try { value = JSON.parse(text()) } catch (e) {}
      shell.layout = Layout.normalize(value)
      shell.layoutRead = true
    }
    onLoadFailed: { shell.layout = Layout.emptyLayout(); shell.layoutRead = true }
  }

  // Monitor `screen`'s cells as they are now; each of `own` lives there from now on.
  function saveScreen(screen, cells, own) {
    shell.layout = Layout.withScreen(shell.layout, screen, cells, own || [])
    if (layoutFile.path) layoutFile.setText(JSON.stringify(shell.layout, null, 2) + "\n")
  }

  // ------------------------------------------------------------ monitors

  readonly property var screenNames: {
    var out = [], all = Quickshell.screens
    for (var i = 0; i < all.length; i++) out.push(String(all[i].name))
    return out
  }
  // Where a widget with no place yet goes: the monitor in use when it turned up.
  property var arrivals: ({})
  readonly property string focusedScreen: {
    var m = Hyprland.focusedMonitor
    var n = m ? String(m.name) : ""
    return shell.screenNames.indexOf(n) >= 0 ? n : (shell.screenNames[0] || "")
  }

  onFilesChanged: {
    var next = {}, changed = false
    for (var i = 0; i < shell.files.length; i++) {
      var f = shell.files[i]
      if (shell.arrivals[f]) next[f] = shell.arrivals[f]
      else if (!Layout.savedScreen(shell.layout, f)) { next[f] = shell.expected[f] || shell.focusedScreen; changed = true }
    }
    if (changed || Object.keys(next).length !== Object.keys(shell.arrivals).length) shell.arrivals = next
  }

  // The monitor a widget shows on: where it was placed while that's connected;
  // else where it arrived, or the first monitor.
  function screenOf(file) {
    var saved = Layout.savedScreen(shell.layout, file)
    if (saved && shell.screenNames.indexOf(saved) >= 0) return saved
    var arrived = shell.arrivals[file]
    if (!saved && arrived && shell.screenNames.indexOf(arrived) >= 0) return arrived
    return shell.screenNames[0] || ""
  }

  // Where a file not there yet goes once it is: the store's monitor, for one
  // installed from it.
  property var expected: ({})
  function expectArrival(file, screen) {
    var next = Object.assign({}, shell.expected)
    next[file] = screen
    shell.expected = next
  }

  // Faces to show on a monitor once they're placed there, in place of the face
  // showing: one added from the store, or its "show it here".
  property var reveal: ({})
  function revealFace(file, screen) {
    if (shell.files.indexOf(file) >= 0 && shell.screenOf(file) !== screen) {
      var arrivals = Object.assign({}, shell.arrivals)
      arrivals[file] = screen
      shell.arrivals = arrivals
      shell.layout = Layout.without(shell.layout, file)
      if (layoutFile.path) layoutFile.setText(JSON.stringify(shell.layout, null, 2) + "\n")
    }
    var next = Object.assign({}, shell.reveal)
    next[file] = screen
    shell.reveal = next
  }
  function revealed(file) {
    var next = Object.assign({}, shell.reveal)
    delete next[file]
    shell.reveal = next
  }

  // Sends a widget to the next monitor, where it takes the first free place.
  function moveToNextScreen(file) {
    if (shell.screenNames.length < 2) return
    var from = shell.screenOf(file)
    var to = shell.screenNames[(shell.screenNames.indexOf(from) + 1) % shell.screenNames.length]
    var arrivals = Object.assign({}, shell.arrivals)
    arrivals[file] = to
    shell.arrivals = arrivals
    shell.layout = Layout.without(shell.layout, file)
    if (layoutFile.path) layoutFile.setText(JSON.stringify(shell.layout, null, 2) + "\n")
  }

  // ------------------------------------------------------------ store records

  // What came from the store ({ "<author/name>": { file, ... } }), as the
  // omarchy-widgets command records it: removed through it, not just hidden.
  property var records: ({})
  FileView {
    path: shell.stateHome + "/omarchy-widgets/installed.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { shell.records = JSON.parse(text()) || {} } catch (e) { shell.records = {} } }
    onLoadFailed: shell.records = {}
  }
  // Faces, which the phone keeps apart: an id may be a widget's and a face's.
  property var faceRecords: ({})
  FileView {
    path: shell.stateHome + "/omarchy-widgets/installed-faces.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { shell.faceRecords = JSON.parse(text()) || {} } catch (e) { shell.faceRecords = {} } }
    onLoadFailed: shell.faceRecords = {}
  }
  // The starter widgets' records, with the SHA-256 of each file as it came.
  property var starterRecords: ({})
  FileView {
    path: shell.appDir + "/starter/installed.json"
    printErrors: false
    onLoaded: { try { shell.starterRecords = JSON.parse(text()) || {} } catch (e) { shell.starterRecords = {} } }
  }
  function storeIdFor(file) {
    for (var id in shell.records) if (shell.records[id].file === file) return id
    for (var fid in shell.faceRecords) if (shell.faceRecords[fid].file === file) return fid
    return ""
  }
  function storeKindFor(file) {
    for (var fid in shell.faceRecords) if (shell.faceRecords[fid].file === file) return "face"
    return "widget"
  }

  // ------------------------------------------------------------ commands

  // Runs a command; then(code, stdout, stderr).
  function run(command, then) {
    var p = runner.createObject(shell, { command: command, then: then || null }) as Process
    p.running = true
  }
  Component {
    id: runner
    Process {
      id: proc
      property var then: null
      stdout: StdioCollector { id: out }
      stderr: StdioCollector { id: err }
      onExited: (code) => {
        if (proc.then) proc.then(code, out.text, err.text)
        proc.destroy(1000)
      }
    }
  }

  // A line of news at the bottom of the desktop: what just happened, or went wrong.
  property string message: ""
  property bool messageIsError: false
  function say(text, error) {
    shell.message = String(text || "").trim()
    shell.messageIsError = !!error
    messageTimer.restart()
    if (error) console.warn("owl-desktop: " + shell.message)
  }
  Timer { id: messageTimer; interval: 8000; onTriggered: shell.message = "" }

  // The omarchy-widgets command, for the store and your agent, as Omalauncher's
  // desktop app runs it; then shows what it said, unless `quiet` (the store
  // says it on the page). done(code, stdout, stderr).
  function widgets(args, done, quiet) {
    shell.run(["env", "OWL_WIDGETS=" + shell.dir, "OMARCHY_WIDGETS_APP=" + shell.appDir, shell.bin].concat(args), function(code, out, err) {
      if (code !== 0 && !quiet) shell.say(err.replace(/^omarchy-widgets: /, "").trim() || "omarchy-widgets " + args[0] + " failed", true)
      else if (code === 0 && out.trim()) shell.say(out.trim().split("\n").pop())
      shell.rescan()
      if (done) done(code, out, err)
    })
  }

  // ------------------------------------------------------------ the store

  // The monitor the store is open on, "" when it's closed; what it opens on.
  property string storeOn: ""
  property string storePick: ""
  property string storeKind: ""
  function openStore(id, kind) {
    shell.storePick = id || ""
    shell.storeKind = kind || ""
    var on = shell.arrangingOn || shell.focusedScreen
    if (shell.storeOn === on) { shell.storeOn = ""; }
    shell.storeOn = on
  }
  function closeStore() { shell.storeOn = "" }

  function create() { shell.widgets(["new"]) }

  // A new desktop starts with Omalauncher's starter widgets, once, where the
  // phone and the desktop app put them: the weather and fetch side by side,
  // the koi pond under them. The desktops place nothing until this is done.
  property bool starterDone: false
  readonly property bool ready: shell.starterDone && shell.layoutRead && shell.scanned
  readonly property var starterLayout: ({
    "market-simonschubert-today.owl": { x: 0, y: 0, w: 3, h: 3 },
    "market-simonschubert-fetch.owl": { x: 3, y: 0, w: 3, h: 3 },
    "market-simonschubert-koi-pond.owl": { x: 0, y: 3, w: 6, h: 3 }
  })
  property bool starterCopied: false
  Component.onCompleted: shell.run(["bash", "-c", "[ -e \"$1\" ]", "starter", shell.stateHome + "/omarchy-widgets/starter"], function(seen) {
    shell.widgets(["starter"], function(code) {
      shell.starterCopied = code === 0 && seen !== 0
      shell.rescan()
      seedLater.restart()
    })
  })
  // Once the folder has been read again with the starters in it.
  Timer {
    id: seedLater
    interval: 300
    onTriggered: {
      if (!shell.layoutRead || scan.running) return seedLater.restart()
      if (shell.starterCopied && Object.keys(shell.layout.screens).length === 0 && shell.focusedScreen) {
        var cells = {}, own = []
        for (var f in shell.starterLayout) if (shell.files.indexOf(f) >= 0) { cells[f] = shell.starterLayout[f]; own.push(f) }
        if (own.length) shell.saveScreen(shell.focusedScreen, cells, own)
      }
      shell.starterDone = true
    }
  }

  // ------------------------------------------------------------ desktops

  // Arranging, on one monitor at a time: "" when not.
  property string arrangingOn: ""
  property string arrangeFile: ""

  Variants {
    id: desktops
    model: Quickshell.screens
    delegate: Desktop {
      app: shell
      host: owlHost
    }
  }

  // The DesktopWindow of each monitor.
  function desks() {
    var out = [], all = desktops.instances
    for (var i = 0; i < all.length; i++) if (all[i] && all[i].desk) out.push(all[i].desk)
    return out
  }

  function desktopFor(name) {
    var all = shell.desks()
    for (var i = 0; i < all.length; i++) if (all[i].name === name) return all[i]
    return null
  }

  // ------------------------------------------------------------ IPC

  // owl-desktop arrange|done|reload|list|screen|style: see bin/owl-desktop.
  IpcHandler {
    target: "owl-desktop"
    function arrange(file: string): string {
      var screen = file ? shell.screenOf(file) : shell.focusedScreen
      shell.arrangeFile = file || ""
      shell.arrangingOn = screen
      return screen ? "ok" : "no monitor"
    }
    function done(): string { shell.arrangingOn = ""; shell.arrangeFile = ""; return "ok" }
    function toggle(): string { if (shell.arrangingOn) return done(); return arrange("") }
    function reload(): string {
      shell.rescan()
      styleFile.reload()
      fontProc.running = true
      var all = shell.desks()
      for (var i = 0; i < all.length; i++) all[i].reloadWidgets()
      return "ok"
    }
    function list(): string {
      var out = []
      var all = shell.desks()
      for (var i = 0; i < all.length; i++) out = out.concat(all[i].describe())
      return JSON.stringify(out, null, 2)
    }
    function screen(file: string): string {
      var d = shell.desktopFor(shell.screenOf(file))
      return d && d.openScreen(file) ? "ok" : "no such widget, or it has no screen { }"
    }
    function style(): string { shell.editStyle(); return "ok" }
    // The store, or the page of one in it (author/name, a widget's or a face's).
    function store(id: string): string { shell.openStore(id, ""); return shell.storeOn ? "ok" : "no monitor" }
  }
}
