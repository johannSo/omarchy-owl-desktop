.pragma library

// The store, as the phone reads and shows it (Omalauncher's Catalog.kt,
// Market.kt and ui/StoreScreen.kt): the reviewed widgets in the store's
// index.json and faces in its faces.json, from its GitHub Pages, and what this
// machine installed from them (installed.json and installed-faces.json, which
// bin/omarchy-widgets writes). Grown from the Omarchy plugin's Store.js (MIT,
// Simon Schubert). Pure functions, so test/store.test.mjs runs them in node.

var REPO = "SimonSchubert/omarchy-widgets"

// The phone's categories, in its order: tabs with as many entries keep it.
var CATEGORIES = ["news", "dev", "productivity", "time", "world", "sport", "finance", "media", "games", "pets", "fun", "home", "system"]

// What the store holds, as the toggle in its header names them.
var KINDS = {
  widget: { key: "widgets", catalog: "index.json", records: "installed.json", plural: "widgets", one: "widget" },
  face: { key: "faces", catalog: "faces.json", records: "installed-faces.json", plural: "faces", one: "face" }
}

function parse(text, key) {
  var value = JSON.parse(text)
  var list = value ? value[key || "widgets"] : null
  if (!Array.isArray(list)) throw new Error("not a store index")
  return list.filter(function (e) {
    return e && typeof e.id === "string" && /^[a-z0-9][a-z0-9-]*\/[a-z0-9][a-z0-9-]*$/.test(e.id)
  })
}

// "1.10" > "1.9"; "1.0" == "1".
function compareVersions(a, b) {
  var x = String(a || "0").split(/[.-]/), y = String(b || "0").split(/[.-]/)
  for (var i = 0; i < Math.max(x.length, y.length); i++) {
    var p = x[i] === undefined ? "0" : x[i], q = y[i] === undefined ? "0" : y[i]
    var n = parseInt(p, 10), m = parseInt(q, 10)
    if (!isNaN(n) && !isNaN(m) && n !== m) return n < m ? -1 : 1
    if (isNaN(n) || isNaN(m)) { if (p !== q) return p < q ? -1 : 1 }
  }
  return 0
}

function same(a, b) { return JSON.stringify(a || null) === JSON.stringify(b || null) }

// Within what this runtime reads: an entry for a newer OWL waits for an update.
function supported(entry, level) { return (entry.owl || 1) <= level }

function hasUpdate(entry, record, level) {
  return !!record && supported(entry, level) && compareVersions(entry.version, record.version) > 0
}

// An update runs other commands or needs other packages than the ones approved.
function changedSinceApproval(entry, record) {
  return !!record && (!same(entry.commands || [], record.commands || []) || !same(entry.requires || {}, record.requires || {}))
}

// Whether updating would throw changes away: "changed" when the file isn't the
// one installed, "unknown" when it was installed without its SHA-256 (the
// phone counts that as edited too), else "". `sha` is the file's now: null
// when it's gone, undefined until it's known.
function edited(record, sha) {
  if (!record || sha === null) return ""
  if (!record.sha256) return "unknown"
  if (sha === undefined) return ""
  return sha === record.sha256 ? "" : "changed"
}

// The store's picture of it in this Omarchy theme, else its own.
function preview(entry, theme) {
  if (entry.themes && theme && entry.themes[theme]) return entry.themes[theme]
  return entry.preview || ""
}

// Its category, or "other" when the store gives it none.
function category(entry) { return entry.category && entry.category !== "other" ? entry.category : "other" }

// The tabs over the grid: all, new, the categories biggest first (ties in the
// phone's order, then by name; one the phone doesn't know yet gets a tab too),
// other, and installed with how many have an update.
function tabs(entries, records, level) {
  records = records || {}
  var out = [{ name: "all", count: entries.length }, { name: "new", count: entries.filter(function (e) { return !!e.new }).length }]
  var counts = {}
  entries.forEach(function (e) { var c = category(e); if (c !== "other") counts[c] = (counts[c] || 0) + 1 })
  var known = function (c) { var i = CATEGORIES.indexOf(c); return i < 0 ? 1e9 : i }
  Object.keys(counts).sort(function (a, b) {
    return counts[b] - counts[a] || known(a) - known(b) || (a < b ? -1 : a > b ? 1 : 0)
  }).forEach(function (c) { out.push({ name: c, count: counts[c] }) })
  var other = entries.filter(function (e) { return category(e) === "other" }).length
  if (other) out.push({ name: "other", count: other })
  var installed = entries.filter(function (e) { return !!records[e.id] })
  out.push({ name: "installed", count: installed.length, updates: installed.filter(function (e) { return hasUpdate(e, records[e.id], level) }).length })
  return out
}

// "dev 30", and "installed 3 · 1↑" with updates.
function tabLabel(tab) {
  return tab.name + " " + tab.count + (tab.updates ? " · " + tab.updates + "↑" : "")
}

// What a tab and a search leave, in the store's order; the new tab newest first.
function shown(entries, records, tab, query) {
  records = records || {}
  var q = String(query || "").trim().toLowerCase()
  var out = entries.filter(function (e) {
    if (tab === "new") return !!e.new
    if (tab === "installed") return !!records[e.id]
    if (tab && tab !== "all") return category(e) === tab
    return true
  }).filter(function (e) {
    if (!q) return true
    return [e.name, e.description, e.author, e.category].some(function (s) { return String(s || "").toLowerCase().indexOf(q) >= 0 })
  })
  if (tab === "new") {
    out = out.map(function (e, i) { return { e: e, i: i } }).sort(function (a, b) {
      var x = a.e.added || "", y = b.e.added || ""
      return x < y ? 1 : x > y ? -1 : a.i - b.i
    }).map(function (p) { return p.e })
  }
  return out
}

function sizeText(entry) { return entry.size && entry.size.length === 2 ? " · " + entry.size[0] + "x" + entry.size[1] : "" }

// A card's line under its name, and the palette color it's in.
function cardStatus(entry, record, level, busy) {
  if (busy) return { text: busy, color: "accent" }
  if (hasUpdate(entry, record, level)) return { text: "update available", color: "accent" }
  if (record) return { text: "✓ installed", color: "green" }
  if (!supported(entry, level)) return { text: "needs a newer launcher", color: "red" }
  return { text: category(entry) + sizeText(entry), color: "muted" }
}

// Its page's line under the name: "world · simonschubert · v1.10 · MIT · 3x3".
function details(entry) {
  return category(entry) + " · " + (entry.author || "") + " · v" + (entry.version || "") + " · " + (entry.license || "") + sizeText(entry)
}

// "pacman: jq, curl; aur: yay", or "none".
function packages(requires) {
  var parts = []
  for (var m in requires || {}) {
    var list = requires[m] || []
    if (list.length) parts.push(m + ": " + list.join(", "))
  }
  return parts.length ? parts.join("; ") : "none"
}

// The file it's installed as: the one its record names, else the phone's name.
function fileFor(entry, record, kind) {
  if (record && record.file) return record.file
  var author = entry.id.split("/")[0], name = entry.id.split("/")[1]
  return (kind === "face" ? "market-face-" : "market-") + author + "-" + name + ".owl"
}
