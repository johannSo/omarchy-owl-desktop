// node test/layout.test.mjs: Layout.js, which QML loads as a .pragma library.
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import assert from "node:assert/strict"

const src = readFileSync(fileURLToPath(new URL("../Layout.js", import.meta.url)), "utf8").replace(/^\.pragma library\s*$/m, "")
const module = { exports: {} }
new Function("module", src)(module)
const L = module.exports

let failed = 0
function test(name, f) {
  try { f(); console.log("ok   " + name) } catch (e) { failed++; console.log("FAIL " + name + "\n     " + e.message) }
}

test("first fit goes top row first, left to right", () => {
  const cells = { a: { x: 0, y: 0, w: 3, h: 2 } }
  assert.deepEqual(L.firstFit(cells, 3, 2, 10, 5), { x: 3, y: 0, w: 3, h: 2 })
  assert.deepEqual(L.firstFit(cells, 8, 2, 10, 5), { x: 0, y: 2, w: 8, h: 2 })
})

test("first fit stays on the screen and gives up when it is full", () => {
  const cells = { a: { x: 0, y: 0, w: 4, h: 4 } }
  assert.equal(L.firstFit(cells, 2, 2, 4, 4), null)
  assert.deepEqual(L.firstFit({}, 9, 9, 4, 3), { x: 0, y: 0, w: 4, h: 3 })
})

test("settle places only widgets whose size is known, keeping the rest", () => {
  const r = L.settle({ a: { x: 0, y: 0, w: 2, h: 2 } }, ["a", "b", "c"], { b: { size: [3, 1] } }, 6, 6)
  assert.deepEqual(r.cells.b, { x: 2, y: 0, w: 3, h: 1 })
  assert.equal(r.cells.c, undefined)
  assert.deepEqual(r.placed, ["b"])
})

test("settle moves a tile that no longer fits a smaller grid", () => {
  const r = L.settle({ a: { x: 8, y: 0, w: 4, h: 2 } }, ["a"], { a: { size: [4, 2] } }, 10, 6)
  assert.deepEqual(r.cells.a, { x: 0, y: 0, w: 4, h: 2 })
})

test("settle keeps hidden tiles hidden", () => {
  const r = L.settle({ a: { x: 0, y: 0, w: 4, h: 2, hidden: true } }, ["a"], { a: { size: [4, 2] } }, 10, 6)
  assert.equal(r.cells.a.hidden, true)
  assert.deepEqual(r.placed, [])
})

test("a face shows behind the tiles, one per monitor", () => {
  const r = L.settle({ t: { x: 0, y: 0, w: 2, h: 2 } }, ["t", "f1", "f2"], { f1: { face: true }, f2: { face: true } }, 6, 6)
  assert.deepEqual(r.cells.f1, { face: true })
  assert.deepEqual(r.cells.f2, { face: true, hidden: true })
  // In nobody's way.
  assert.ok(L.move(r.cells, "t", 3, 3, 6, 6))
  const shown = L.show(r.cells, "f2", [6, 6], true, 6, 6)
  assert.equal(shown.f1.hidden, true)
  assert.equal(shown.f2.hidden, undefined)
})

test("a widget that turns into a face starts again", () => {
  const r = L.settle({ f: { x: 0, y: 0, w: 2, h: 2 } }, ["f"], { f: { face: true } }, 6, 6)
  assert.deepEqual(r.cells.f, { face: true })
})

test("moves and resizes refuse overlaps and the screen's edges", () => {
  const cells = { a: { x: 0, y: 0, w: 2, h: 2 }, b: { x: 3, y: 0, w: 2, h: 2 } }
  assert.equal(L.move(cells, "a", 2, 0, 6, 4), null)
  assert.equal(L.move(cells, "a", 0, 3, 6, 4), null)
  assert.deepEqual(L.move(cells, "a", 0, 2, 6, 4).a, { x: 0, y: 2, w: 2, h: 2 })
  assert.equal(L.resize(cells, "a", 4, 2, [1, 1], 6, 4), null)
  assert.deepEqual(L.resize(cells, "a", 1, 1, [2, 1], 6, 4).a, { x: 0, y: 0, w: 2, h: 1 })
})

test("an edge drag keeps minSize and the grid", () => {
  const c = { x: 2, y: 2, w: 2, h: 2 }
  assert.deepEqual(L.edge(c, { left: true }, -5, 0, [1, 1], 6, 6), { x: 0, y: 2, w: 4, h: 2 })
  assert.deepEqual(L.edge(c, { bottom: true }, 0, 9, [1, 1], 6, 6), { x: 2, y: 2, w: 2, h: 4 })
  assert.deepEqual(L.edge(c, { right: true }, -5, 0, [2, 1], 6, 6), { x: 2, y: 2, w: 2, h: 2 })
})

test("the grid stretches its cells to the margins", () => {
  const g = L.grid(1920, 1174, 69, 6, 6)
  assert.equal(g.columns, 27)
  assert.equal(g.rows, 16)
  const last = L.rect(g, { x: g.columns - 1, y: g.rows - 1, w: 1, h: 1 })
  assert.equal(last.x + last.width, 1920 - 6)
  assert.equal(last.y + last.height, 1174 - 6)
  assert.deepEqual(L.rect(g, { x: 0, y: 0, w: 1, h: 1 }).x, 6)
})

test("lines run down the middle of the gaps", () => {
  const g = L.grid(1920, 1174, 69, 6, 6)
  assert.equal(L.colLine(g, 6), 0)
  assert.equal(L.colLine(g, 6 + 3 * g.cellW - 3), 3)
  assert.equal(L.colLine(g, 99999), g.columns)
})

test("a file lives on one monitor", () => {
  let layout = L.normalize({ screens: { A: { w: { x: 0, y: 0, w: 2, h: 2 } } } })
  assert.equal(L.screenFor(layout, "w", ["A", "B"], "B"), "A")
  assert.equal(L.screenFor(layout, "w", ["B"], "B"), "B")
  assert.equal(L.screenFor(layout, "new", ["A", "B"], "B"), "B")
  layout = L.withScreen(layout, "B", { w: { x: 1, y: 1, w: 2, h: 2 } }, ["w"])
  assert.equal(layout.screens.A.w, undefined)
  assert.deepEqual(layout.screens.B.w, { x: 1, y: 1, w: 2, h: 2 })
  assert.equal(L.savedScreen(L.without(layout, "w"), "w"), "")
})

test("a broken layout file reads as empty", () => {
  assert.deepEqual(L.normalize(null), { version: 1, screens: {} })
  assert.deepEqual(L.normalize([1]), { version: 1, screens: {} })
  assert.deepEqual(L.normalize({ screens: { A: [1], B: { f: 3, g: { x: 1 } } } }), { version: 1, screens: { B: { g: { x: 1 } } } })
})

if (failed) { console.log(failed + " failed"); process.exit(1) }
console.log("all passed")
