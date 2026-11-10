.pragma library

// How the desktop's widgets look: ~/.config/owl-desktop/style.toml, with
// OmaLauncher++'s own names, defaults and ranges (theme/Style.kt in
// omalauncher.pp) where the phone has the setting, and [desktop] for what only
// a desktop needs.

var DEFAULTS = {
  // Space in dp between two widgets, and from them to the screen's edges.
  gapsIn: 6,
  gapsOut: 6,
  // How much a widget covers the wallpaper: 0 clear, 1 solid (the launcher's GLASS).
  opacity: 0.88,
  // How thick widgets' outlines are, in dp; 0 draws none, but the focused one's.
  borderWidth: 2,
  // "theme" is the theme's border color (its muted) and accent; else a theme color name or #rrggbb.
  border: "theme",
  borderFocused: "theme",
  // Multiplies every frame's corner radius, as OmaLauncher++'s corners.scale: 0 square (Omarchy), 0.5 soft, 1 round.
  cornerScale: 0,
  // px per dp: how big everything is drawn. 1 is the launcher's size on a phone at its density.
  scale: 1,
  // A grid cell in dp, the gap after it included: the launcher's.
  cell: 69,
  // Where the widgets are: shared with Omalauncher's desktop app and its store.
  folder: "~/.config/omarchy-widgets",
  // Widgets stop their sources and animations while tiled windows cover the desktop.
  pauseWhenCovered: true,
  // Frames a second an animated widget draws, at most (the runtime's default is 30).
  frameRate: 30
}

var KEYS = {
  "widgets.gaps-in": ["gapsIn", 0, 24],
  "widgets.gaps-out": ["gapsOut", 0, 48],
  "widgets.opacity": ["opacity", 0, 1],
  "widgets.border-width": ["borderWidth", 0, 8],
  "widgets.border": ["border"],
  "widgets.border-focused": ["borderFocused"],
  "corners.scale": ["cornerScale", 0, 2],
  "desktop.scale": ["scale", 0.5, 4],
  "desktop.cell": ["cell", 40, 200],
  "desktop.folder": ["folder"],
  "desktop.pause-when-covered": ["pauseWhenCovered"],
  "desktop.frame-rate": ["frameRate", 1, 60]
}

function value(raw) {
  var v = raw.trim()
  var q = /^"((?:[^"\\]|\\.)*)"/.exec(v) || /^'([^']*)'/.exec(v)
  if (q) return q[1].replace(/\\(.)/g, "$1")
  v = v.replace(/\s+#.*$/, "").trim()
  if (v === "true") return true
  if (v === "false") return false
  var n = Number(v)
  return v !== "" && isFinite(n) ? n : null
}

// The settings in `text`, each checked against its default's type and range;
// anything else is the default. Returns { style, problems }.
function parse(text) {
  var style = Object.assign({}, DEFAULTS), problems = []
  var section = ""
  String(text || "").split("\n").forEach(function (line, i) {
    var l = line.replace(/^\s+/, "")
    if (l === "" || l[0] === "#") return
    var s = /^\[([A-Za-z0-9_.-]+)\]\s*(#.*)?$/.exec(l)
    if (s) { section = s[1]; return }
    var kv = /^([A-Za-z0-9_-]+)\s*=\s*(.*)$/.exec(l)
    if (!kv) { problems.push("style.toml:" + (i + 1) + ": not a setting"); return }
    var key = (section ? section + "." : "") + kv[1]
    var spec = KEYS[key]
    if (!spec) { problems.push("style.toml:" + (i + 1) + ": unknown setting " + key); return }
    var v = value(kv[2]), name = spec[0], def = DEFAULTS[name]
    if (v === null || typeof v !== typeof def) { problems.push("style.toml:" + (i + 1) + ": " + key + " takes " + (typeof def === "number" ? "a number" : typeof def === "boolean" ? "true or false" : "text in quotes")); return }
    if (typeof v === "number") v = Math.max(spec[1], Math.min(spec[2], v))
    style[name] = v
  })
  return { style: style, problems: problems }
}

var TEMPLATE = [
  "# How the desktop's OWL widgets look. Saved changes apply at once.",
  "# The [widgets] and [corners] settings are OmaLauncher++'s (its style.toml), with its defaults.",
  "",
  "[widgets]",
  "gaps-in = 6            # dp between two widgets (0-24)",
  "gaps-out = 6           # dp from the widgets to the screen's edges (0-48)",
  "opacity = 0.88         # how much a widget covers the wallpaper: 0 clear, 1 solid",
  "border-width = 2       # widgets' outlines in dp; 0 draws none (0-8)",
  "border = \"theme\"       # \"theme\" (the theme's muted), a theme color like \"accent\", or \"#rrggbb\"",
  "border-focused = \"theme\" # the widget being typed into or arranged: \"theme\" is the accent",
  "",
  "[corners]",
  "scale = 0              # every frame's corner radius: 0 square (Omarchy), 0.5 soft, 1 round (0-2)",
  "",
  "[desktop]",
  "scale = 1              # px per dp: 1.25 draws everything a quarter bigger",
  "cell = 69              # a grid cell in dp, gap included: the launcher's",
  "folder = \"~/.config/omarchy-widgets\"  # the .owl files, shared with Omalauncher's desktop app",
  "pause-when-covered = true  # stop sources and animations while tiled windows cover the desktop",
  "frame-rate = 30        # the most frames a second an animated widget draws (1-60)",
  ""
].join("\n")

if (typeof module !== "undefined" && module.exports) module.exports = { DEFAULTS: DEFAULTS, parse: parse, TEMPLATE: TEMPLATE }
