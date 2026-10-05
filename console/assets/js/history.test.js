// node --test assets/js/*.test.js
import { test } from "node:test"
import assert from "node:assert/strict"
import { History } from "./history.js"

const withLines = (...lines) => { const h = new History(); for (const l of lines) h.push(l); return h }

test("↑ with nothing behind leaves the line being written", () => {
  const h = new History()
  assert.equal(h.up("half a comm"), "half a comm")
  assert.equal(h.down("half a comm"), "half a comm")
})

test("↓ past the newest line gives back the line being written", () => {
  const h = withLines("line 1")
  assert.equal(h.up("draft"), "line 1")
  assert.equal(h.down("line 1"), "draft")
  assert.equal(h.down("draft"), "draft")
})

test("↑ brings the newest line first, then the older ones", () => {
  const h = withLines("line 1", "line 2")
  assert.equal(h.up(""), "line 2")
  assert.equal(h.up("line 2"), "line 1")
})

test("three lines walk back and forth one step at a time", () => {
  const h = withLines("line 1", "line 2", "line 3")
  assert.equal(h.up("draft"), "line 3")
  assert.equal(h.up("line 3"), "line 2")
  assert.equal(h.up("line 2"), "line 1")
  assert.equal(h.up("line 1"), "line 1")
  assert.equal(h.down("line 1"), "line 2")
  assert.equal(h.down("line 2"), "line 3")
  assert.equal(h.down("line 3"), "draft")
})

test("the draft is taken when ↑ leaves it, not kept from an earlier walk", () => {
  const h = withLines("line 1")
  h.up("first"); h.down("line 1")
  assert.equal(h.up("second"), "line 1")
  assert.equal(h.down("line 1"), "second")
})

test("sending a line starts the walk again from the newest", () => {
  const h = withLines("line 1", "line 2")
  h.up(""); h.up("line 2")
  h.push("line 3")
  assert.equal(h.up(""), "line 3")
  assert.equal(h.down("line 3"), "")
})

test("blank lines are not kept, nor a repeat of the newest", () => {
  const h = withLines("line 1", "  ", "line 1")
  assert.deepEqual(h.items, ["line 1"])
})

test("the oldest lines fall off past the limit", () => {
  const h = new History(2)
  for (const l of ["a", "b", "c"]) h.push(l)
  assert.deepEqual(h.items, ["c", "b"])
})
