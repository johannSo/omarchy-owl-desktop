.pragma library

// Where each widget sits on a monitor's grid, as pure functions over a map of
//
//   { "<file, relative to the widget folder>": { x, y, w, h, hidden? } }
//
// in grid cells, one map per monitor. A face (a whole page, `face "…" { }`)
// takes the whole grid behind the tiles and is kept as { face: true, hidden? }:
// it is in nobody's way, and only one shows per monitor.
//
// Adapted from Omalauncher's desktop board (BoardLayout.js in
// omalauncher-omarchy-plugin, MIT): the board scrolls, so it only has columns;
// a desktop has rows too, and a tile must stay on the screen.
//
// Every function returns a new map, or null when the change does not fit: two
// tiles never overlap, and a tile never leaves the grid. Nothing here touches
// QML, so test/layout.test.mjs runs it under node.

function isFace(c) { return !!c && c.face === true }

function overlaps(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h
}

function valid(c, columns, rows) {
  if (isFace(c)) return true
  return !!c && [c.x, c.y, c.w, c.h].every(function (n) { return typeof n === "number" && Math.floor(n) === n })
    && c.x >= 0 && c.y >= 0 && c.w >= 1 && c.h >= 1 && c.x + c.w <= columns && c.y + c.h <= rows
}

function copy(cells) {
  var out = {}
  for (var k in cells) out[k] = Object.assign({}, cells[k])
  return out
}

// Is `cell` clear of every shown tile but `self`? Only files on the desktop
// now count: a file that went away leaves its place behind, but not in the way.
function clear(cells, cell, self, present) {
  for (var k in cells) {
    var c = cells[k]
    if (k === self || c.hidden || isFace(c)) continue
    if (present && present.indexOf(k) < 0) continue
    if (overlaps(cell, c)) return false
  }
  return true
}

// The first free place for a w x h tile, top row first, left to right: the
// launcher's own rule for a new widget. Null when the screen is full.
function firstFit(cells, w, h, columns, rows, self, present) {
  w = Math.min(w, columns)
  h = Math.min(h, rows)
  for (var y = 0; y + h <= rows; y++)
    for (var x = 0; x + w <= columns; x++) {
      var c = { x: x, y: y, w: w, h: h }
      if (clear(cells, c, self, present)) return c
    }
  return null
}

// Is a face showing on this grid, other than `self`?
function faceShown(cells, self, present) {
  for (var k in cells) {
    if (k === self || !isFace(cells[k]) || cells[k].hidden) continue
    if (present && present.indexOf(k) < 0) continue
    return k
  }
  return ""
}

// Gives every file on this monitor a place. `files` are the widgets that live
// here, in order; `sizes` maps the ones compiled so far to { size: [w, h],
// face }. A file is placed only once its size is known, so nothing saves a
// guess. A tile that no longer fits -- a smaller monitor, a bigger scale --
// moves to the first free place. A file with no room left is not placed and
// waits. Returns { cells, placed: [files given a new place] }.
function settle(cells, files, sizes, columns, rows) {
  var out = copy(cells || {}), placed = []
  var present = files.filter(function (f) { return out[f] && !out[f].hidden && valid(out[f], columns, rows) })
  for (var i = 0; i < files.length; i++) {
    var f = files[i], c = out[f], s = sizes[f]
    // A file that turned into a face, or out of one, starts again.
    if (c && s && isFace(c) !== !!s.face) c = null
    if (c && (c.hidden || valid(c, columns, rows))) continue
    if (!s) continue
    if (s.face) {
      out[f] = faceShown(out, f, present) ? { face: true, hidden: true } : { face: true }
    } else {
      var w = c ? c.w : s.size[0], h = c ? c.h : s.size[1]
      var at = firstFit(out, w, h, columns, rows, f, present)
      if (!at) continue
      out[f] = at
    }
    present.push(f)
    placed.push(f)
  }
  return { cells: out, placed: placed }
}

function move(cells, file, x, y, columns, rows, present) {
  var c = cells[file]
  if (!c || isFace(c)) return null
  var next = { x: x, y: y, w: c.w, h: c.h }
  if (!valid(next, columns, rows) || !clear(cells, next, file, present)) return null
  var out = copy(cells)
  out[file] = next
  return out
}

// `min` is the widget's minSize: it never shrinks below what its layout fits.
function resize(cells, file, w, h, min, columns, rows, present) {
  var c = cells[file]
  if (!c || isFace(c)) return null
  var next = { x: c.x, y: c.y, w: Math.max(w, min[0]), h: Math.max(h, min[1]) }
  if (!valid(next, columns, rows) || !clear(cells, next, file, present)) return null
  var out = copy(cells)
  out[file] = next
  return out
}

// The cell an edge drag makes, as on the phone: `edges` is which sides move
// ({left, top, right, bottom}), `dx` and `dy` how far in cells. The opposite
// side stays put; the tile keeps the widget's minSize and stays on the grid.
function edge(c, edges, dx, dy, min, columns, rows) {
  var l = c.x, t = c.y, r = c.x + c.w, b = c.y + c.h
  if (edges.left) l = Math.max(0, Math.min(l + dx, r - min[0]))
  if (edges.right) r = Math.min(columns, Math.max(r + dx, l + min[0]))
  if (edges.top) t = Math.max(0, Math.min(t + dy, b - min[1]))
  if (edges.bottom) b = Math.min(rows, Math.max(b + dy, t + min[1]))
  return { x: l, y: t, w: r - l, h: b - t }
}

// `file` at `next`, when that is on the grid and clear of the other tiles.
function place(cells, file, next, columns, rows, present) {
  if (!cells[file] || isFace(cells[file]) || !valid(next, columns, rows) || !clear(cells, next, file, present)) return null
  var out = copy(cells)
  out[file] = { x: next.x, y: next.y, w: next.w, h: next.h }
  return out
}

function hide(cells, file) {
  if (!cells[file]) return null
  var out = copy(cells)
  out[file].hidden = true
  return out
}

// Back on the desktop at its own size, in the first place it fits. A face
// takes the place of the one showing, which goes to the hidden list.
function show(cells, file, size, face, columns, rows, present) {
  var out = copy(cells)
  if (face) {
    var other = faceShown(out, file, present)
    if (other) out[other].hidden = true
    out[file] = { face: true }
    return out
  }
  var at = firstFit(cells, size[0], size[1], columns, rows, file, present)
  if (!at) return null
  out[file] = at
  return out
}

// The grid of a monitor `width` x `height` px: as many cells of `pitch` px
// (gap included) as fit, stretched a little to meet the edges `margin` px from
// them, as the launcher's home grid stretches its cells to the phone's width.
function grid(width, height, pitch, gap, margin) {
  var across = width - 2 * margin + gap, down = height - 2 * margin + gap
  var columns = Math.max(1, Math.floor(across / pitch + 1e-6))
  var rows = Math.max(1, Math.floor(down / pitch + 1e-6))
  return { columns: columns, rows: rows, cellW: across / columns, cellH: down / rows, gap: gap, margin: margin }
}

// A cell's rectangle in px on grid `g`, the gap after it left out.
function rect(g, c) {
  var l = Math.round(g.margin + c.x * g.cellW), t = Math.round(g.margin + c.y * g.cellH)
  return {
    x: l,
    y: t,
    width: Math.round(g.margin + (c.x + c.w) * g.cellW - g.gap) - l,
    height: Math.round(g.margin + (c.y + c.h) * g.cellH - g.gap) - t
  }
}

// The column and row line nearest a point, lines running down the middle of
// the gaps (HomeGrid.kt's colLine and rowLine).
function colLine(g, px) { return Math.max(0, Math.min(g.columns, Math.round((px - g.margin + g.gap / 2) / g.cellW))) }
function rowLine(g, py) { return Math.max(0, Math.min(g.rows, Math.round((py - g.margin + g.gap / 2) / g.cellH))) }

// ----------------------------------------------------------- monitors

// The saved layout: { version: 1, screens: { "<monitor>": cells } }.
function emptyLayout() { return { version: 1, screens: {} } }

function normalize(value) {
  var out = emptyLayout()
  if (!value || typeof value !== "object" || Array.isArray(value)) return out
  var screens = value.screens && typeof value.screens === "object" && !Array.isArray(value.screens) ? value.screens : {}
  for (var s in screens) {
    var cells = screens[s]
    if (!cells || typeof cells !== "object" || Array.isArray(cells)) continue
    out.screens[s] = {}
    for (var f in cells) if (cells[f] && typeof cells[f] === "object") out.screens[s][f] = Object.assign({}, cells[f])
  }
  return out
}

// The monitor a file was placed on, or "".
function savedScreen(layout, file) {
  for (var s in layout.screens) if (layout.screens[s][file]) return s
  return ""
}

// Where a file shows: the monitor it was placed on while that is connected,
// else `fallback` (the one a new widget goes to).
function screenFor(layout, file, connected, fallback) {
  var s = savedScreen(layout, file)
  return s && connected.indexOf(s) >= 0 ? s : fallback
}

// `layout` with `cells` as monitor `screen`'s, and each file in `own` taken off
// every other monitor: a file lives on one.
function withScreen(layout, screen, cells, own) {
  var out = normalize(layout)
  out.screens[screen] = copy(cells)
  for (var s in out.screens) {
    if (s === screen) continue
    for (var i = 0; i < own.length; i++) delete out.screens[s][own[i]]
  }
  return out
}

// `layout` without `file` anywhere: it moves to another monitor, where it is
// placed as new.
function without(layout, file) {
  var out = normalize(layout)
  for (var s in out.screens) delete out.screens[s][file]
  return out
}

// What has changed between two cell maps: the files whose cell differs.
function changed(a, b) {
  var out = []
  var keys = {}
  for (var k in a) keys[k] = true
  for (var k2 in b) keys[k2] = true
  for (var f in keys) if (JSON.stringify(a[f] || null) !== JSON.stringify(b[f] || null)) out.push(f)
  return out
}

// QML's JS engine has no `module`; node does, and the tests use it.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    isFace: isFace, overlaps: overlaps, valid: valid, clear: clear, firstFit: firstFit, faceShown: faceShown,
    settle: settle, move: move, resize: resize, edge: edge, place: place, hide: hide, show: show,
    grid: grid, rect: rect, colLine: colLine, rowLine: rowLine,
    emptyLayout: emptyLayout, normalize: normalize, savedScreen: savedScreen, screenFor: screenFor,
    withScreen: withScreen, without: without, changed: changed
  }
}
