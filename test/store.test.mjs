// Store.js under node: node test/store.test.mjs

import { readFileSync } from "node:fs"
import assert from "node:assert/strict"

const src = readFileSync(new URL("../Store.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/, "")
const S = new Function(src + "\nreturn { REPO, CATEGORIES, KINDS, parse, compareVersions, supported, hasUpdate, changedSinceApproval, edited, preview, category, tabs, tabLabel, shown, cardStatus, details, packages, fileFor }")()

let failed = 0
function test(name, fn) {
  try { fn(); console.log("ok   " + name) } catch (e) { failed++; console.log("FAIL " + name + "\n     " + e.message) }
}

const LEVEL = 19
const today = { id: "simonschubert/today", name: "today", author: "simonschubert", version: "1.10", license: "MIT", category: "world", size: [3, 3], owl: 17,
  description: "The date and the weather", commands: ["curl wttr.in"], requires: {}, sha256: "aa", preview: "p/today.png", themes: { "tokyo-night": "p/today-tn.webp" }, added: "2026-10-03" }
const fetch = { id: "simonschubert/fetch", name: "fetch", author: "simonschubert", version: "1.9", license: "MIT", category: "system", size: [3, 3], owl: 12,
  commands: ["uname -r"], requires: { pacman: ["jq"] }, sha256: "bb", added: "2026-10-01" }
const fresh = { id: "someone/fresh", name: "fresh", author: "someone", version: "1.0", category: "system", new: true, added: "2026-11-09", owl: 25 }
const older = { id: "someone/older", name: "older", author: "someone", version: "1.0", new: true, added: "2026-11-08" }
const all = [today, fetch, fresh, older]

test("the index is read for its kind, and odd ids are left out", () => {
  const text = JSON.stringify({ widgets: [today, { id: "../etc" }, null], faces: [{ id: "a/b" }] })
  assert.deepEqual(S.parse(text, "widgets").map((e) => e.id), ["simonschubert/today"])
  assert.deepEqual(S.parse(text, "faces").map((e) => e.id), ["a/b"])
  assert.throws(() => S.parse("{}", "faces"))
})

test("versions compare as numbers", () => {
  assert.equal(S.compareVersions("1.10", "1.9"), 1)
  assert.equal(S.compareVersions("1.0", "1"), 0)
  assert.equal(S.compareVersions("1.2", "1.10"), -1)
})

test("an update needs a newer version this runtime can read", () => {
  assert.equal(S.hasUpdate(today, { version: "1.2" }, LEVEL), true)
  assert.equal(S.hasUpdate(today, { version: "1.10" }, LEVEL), false)
  assert.equal(S.hasUpdate(today, null, LEVEL), false)
  assert.equal(S.hasUpdate({ ...today, owl: 20 }, { version: "1.2" }, LEVEL), false)
})

test("an update that runs or needs something else asks again", () => {
  assert.equal(S.changedSinceApproval(fetch, { commands: ["uname -r"], requires: { pacman: ["jq"] } }), false)
  assert.equal(S.changedSinceApproval(fetch, { commands: ["uname -a"], requires: { pacman: ["jq"] } }), true)
  assert.equal(S.changedSinceApproval(fetch, { commands: ["uname -r"], requires: {} }), true)
})

test("edited: a file that isn't the one installed, or one installed without its hash", () => {
  assert.equal(S.edited(null, "x"), "")
  assert.equal(S.edited({ sha256: "aa" }, "aa"), "")
  assert.equal(S.edited({ sha256: "aa" }, "ab"), "changed")
  assert.equal(S.edited({ sha256: "aa" }, undefined), "")
  assert.equal(S.edited({ sha256: "aa" }, null), "")
  assert.equal(S.edited({}, "ab"), "unknown")
})

test("the preview in this theme, else its own", () => {
  assert.equal(S.preview(today, "tokyo-night"), "p/today-tn.webp")
  assert.equal(S.preview(today, "nord"), "p/today.png")
  assert.equal(S.preview(fetch, "nord"), "")
})

test("tabs: all, new, categories biggest first, other, installed with updates", () => {
  const records = { "simonschubert/today": { version: "1.2" }, "simonschubert/fetch": { version: "1.9" } }
  const t = S.tabs(all, records, LEVEL)
  assert.deepEqual(t.map(S.tabLabel), ["all 4", "new 2", "system 2", "world 1", "other 1", "installed 2 · 1↑"])
  assert.deepEqual(S.tabs([], {}, LEVEL).map(S.tabLabel), ["all 0", "new 0", "installed 0"])
})

test("ties keep the phone's order, then a category it doesn't know", () => {
  const e = (id, category) => ({ id: "a/" + id, name: id, category })
  const t = S.tabs([e("x", "zebra"), e("y", "fun"), e("z", "news")], {}, LEVEL).map((t) => t.name)
  assert.deepEqual(t, ["all", "new", "news", "fun", "zebra", "installed"])
})

test("a tab and a search leave what they match, the new tab newest first", () => {
  const records = { "simonschubert/today": { version: "1.2" } }
  assert.deepEqual(S.shown(all, records, "all", "").map((e) => e.name), ["today", "fetch", "fresh", "older"])
  assert.deepEqual(S.shown(all, records, "system", "").map((e) => e.name), ["fetch", "fresh"])
  assert.deepEqual(S.shown(all, records, "other", "").map((e) => e.name), ["older"])
  assert.deepEqual(S.shown(all, records, "installed", "").map((e) => e.name), ["today"])
  assert.deepEqual(S.shown([older, fresh], records, "new", "").map((e) => e.name), ["fresh", "older"])
  assert.deepEqual(S.shown(all, records, "all", "  WEATHER ").map((e) => e.name), ["today"])
  assert.deepEqual(S.shown(all, records, "all", "someone").map((e) => e.name), ["fresh", "older"])
})

test("a card says what it is, or that it's installed, has an update or needs more", () => {
  assert.deepEqual(S.cardStatus(today, null, LEVEL, ""), { text: "world · 3x3", color: "muted" })
  assert.deepEqual(S.cardStatus(today, { version: "1.2" }, LEVEL, ""), { text: "update available", color: "accent" })
  assert.deepEqual(S.cardStatus(today, { version: "1.10" }, LEVEL, ""), { text: "✓ installed", color: "green" })
  assert.deepEqual(S.cardStatus(fresh, null, LEVEL, ""), { text: "needs a newer launcher", color: "red" })
  assert.deepEqual(S.cardStatus(older, null, LEVEL, ""), { text: "other", color: "muted" })
  assert.deepEqual(S.cardStatus(today, null, LEVEL, "installing…"), { text: "installing…", color: "accent" })
})

test("a page's details and packages", () => {
  assert.equal(S.details(today), "world · simonschubert · v1.10 · MIT · 3x3")
  assert.equal(S.packages(fetch.requires), "pacman: jq")
  assert.equal(S.packages({ pacman: ["jq", "curl"], aur: ["yay"] }), "pacman: jq, curl; aur: yay")
  assert.equal(S.packages({}), "none")
})

test("the file it installs as, as the phone names it", () => {
  assert.equal(S.fileFor(today, null, "widget"), "market-simonschubert-today.owl")
  assert.equal(S.fileFor({ id: "simonschubert/manga" }, null, "face"), "market-face-simonschubert-manga.owl")
  assert.equal(S.fileFor(today, { file: "mine.owl" }, "widget"), "mine.owl")
})

if (failed) { console.log(failed + " failed"); process.exit(1) }
console.log("all passed")
