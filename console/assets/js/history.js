// A command line's history, as a shell keeps it: ↑ walks back from the
// newest line, ↓ walks forward, and past the newest ↓ gives back the line
// being written when ↑ was first pressed. With nothing behind, ↑ leaves
// the line alone. Its own module so `node --test` can reach it without a
// browser: `node --test assets/js/*.test.js`.
export class History {
  constructor(limit = 100) { this.items = []; this.sel = -1; this.draft = ""; this.limit = limit }
  push(msg) {
    this.sel = -1; this.draft = ""
    if (!msg.trim()) return
    if (this.items[0] !== msg) this.items.unshift(msg)
    while (this.items.length > this.limit) this.items.pop()
  }
  // One step back; `line` is what the input holds now.
  up(line) {
    if (this.items.length === 0) return line
    if (this.sel === -1) this.draft = line
    this.sel = Math.min(this.sel + 1, this.items.length - 1)
    return this.items[this.sel]
  }
  // One step forward; at the draft already, the line stays as it is.
  down(line) {
    if (this.sel === -1) return line
    this.sel -= 1
    return this.sel >= 0 ? this.items[this.sel] : this.draft
  }
}
