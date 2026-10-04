// The client owns the reader's arrangement — the rail's width, the
// ground, the clock — and the line editing the server has no business
// in: history and Tab completion on the wb.sh line. Kept in this
// browser (localStorage), never in config.conf.

import { History } from "./history"

const store = {
  get(k) { try { return localStorage.getItem(k) } catch (e) { return null } },
  set(k, v) { try { localStorage.setItem(k, v) } catch (e) {} },
}

// --- the wb.sh line: history and completion, as the Assistant Terminal does them
// Tab completes to the next divergence — the longest prefix every candidate shares.
class Trie {
  constructor(words = []) { this.root = { children: {}, data: "", terminal: false }; for (const w of words) this.add(w) }
  add(word) { let node = this.root; for (let i = 0; i < word.length; i++) { const c = word[i]; if (!node.children[c]) node.children[c] = { children: {}, data: word.slice(0, i + 1), terminal: false }; node = node.children[c] } if (node !== this.root) node.terminal = true }
  nextDivergence(prefix) { let node = this.root; for (const c of prefix) { node = node.children[c]; if (!node) return null } while (Object.keys(node.children).length === 1 && !node.terminal) node = Object.values(node.children)[0]; return node.data }
  matches(prefix) { let node = this.root; for (const c of prefix) { node = node.children[c]; if (!node) return [] } const out = []; const walk = n => { if (n.terminal) out.push(n.data); for (const ch of Object.values(n.children)) walk(ch) }; walk(node); return out.sort() }
}
function completeLine(line, trie, say) {
  const full = trie.nextDivergence(line)
  if (full !== null && full !== line) return full
  const at = line.lastIndexOf(" ") + 1, word = line.slice(at), whole = trie.nextDivergence(word)
  if (whole === null) { if (full === line) { const ms = trie.matches(line); if (ms.length > 1 && say) say(ms.join(" · ")) } return line }
  if (whole === word) { const ms = trie.matches(word); if (ms.length > 1 && say) say(ms.join(" · ")); return line }
  return line.slice(0, at) + whole
}
// What Tab can complete to, from the catalog the server put on the input.
function cliWords(words, line) {
  const parts = line.split(/\s+/)
  if (parts.length <= 1) return words.commands
  const [cmd, name] = parts
  if (cmd === "add" || cmd === "eject" || cmd === "expand") {
    if (parts.length === 2) return words.cartridges
    return words.options[name] || []
  }
  if (["up", "build", "logs", "stop", "down", "iex", "bash"].includes(cmd)) return parts.at(-2) === "--deploy" ? words.targets : words.deploy
  if (cmd === "setup" || cmd === "demo") return ["--env"]
  return []
}

export const Cli = {
  mounted() {
    const words = JSON.parse(this.el.dataset.words || "{}")
    const history = new History()
    // The candidates Tab could not choose between, on the line over the
    // field (#cli-help, the form's): there until the next key, as a
    // shell leaves them above the prompt. A toast over the page until
    // 2026-09-27, gone on its own after six seconds.
    const help = document.getElementById("cli-help")
    const say = text => { if (!help) return; help.textContent = text || ""; help.hidden = !text }
    this.el.addEventListener("input", () => say(""))
    this.el.addEventListener("keydown", ev => {
      if (ev.key === "Enter") { say(""); history.push(this.el.value); /* the form submits */ setTimeout(() => { this.el.value = "" }, 0) }
      else if (ev.key === "ArrowUp") { ev.preventDefault(); say(""); this.el.value = history.up(this.el.value) }
      else if (ev.key === "ArrowDown") { ev.preventDefault(); say(""); this.el.value = history.down(this.el.value) }
      else if (ev.key === "Escape") { say("") }
      else if (ev.key === "Tab") {
        ev.preventDefault()
        say("")
        this.el.value = completeLine(this.el.value, new Trie(cliWords(words, this.el.value)), say)
      }
    })
  },
  updated() { /* the words may change with the catalog; read them again on the next Tab */ },
}

// --- the clock in the band
export const Clock = {
  mounted() {
    const tick = () => { this.el.textContent = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) }
    tick(); this.timer = setInterval(tick, 30000)
  },
  destroyed() { clearInterval(this.timer) },
}

// --- the ground the page is read on: follow the machine until the reader has an opinion
const THEME_KEY = "wb-console-ground"
const ground = () => document.documentElement.getAttribute("data-theme") || (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
export const Ground = {
  mounted() {
    const saved = store.get(THEME_KEY)
    if (saved) document.documentElement.setAttribute("data-theme", saved)
    const paint = () => { const t = ground(); this.el.setAttribute("aria-pressed", String(t === "dark")); this.el.title = t === "dark" ? "Dark ground — click for light" : "Light ground — click for dark" }
    this.el.addEventListener("click", () => { const t = ground() === "dark" ? "light" : "dark"; document.documentElement.setAttribute("data-theme", t); store.set(THEME_KEY, t); paint() })
    matchMedia("(prefers-color-scheme: dark)").addEventListener("change", paint)
    // The drawer switches the ground too, and says so here (Frame, setGround).
    this.el.addEventListener("repaint", paint)
    paint()
  },
}

// --- how tall an output pane is allowed to be. A grip under each pane,
// made like the rail's: it moves a variable, one per pane, kept in this
// browser under the pane's name; config.conf never hears about it. The
// variable and not a height, because `.out` reads it with the default
// in the fallback — a pane that was never dragged has nothing written
// on it, and a double-click takes it back to that.
// A pane is whatever wears `data-tall`: a job's row in the jobs tray
// and a box's runs, named by the job's id; the compose file under the
// Record's deployments, named once. The hook rides the list, or the
// pane itself. What is kept for a name that has left the list is
// dropped, except for names that are not jobs — the compose box comes
// and goes with the paper, and keeps its height.
// The browser's own `resize` did this first: its grip sits in the
// corner where the scrollbar ends, and that corner is the browser's to
// paint — a white square on a terminal ground, and only ever when the
// output was long enough to scroll.
const JOB_OUT_KEY = "wb-console-job-out", JOB_OUT_MIN = 80, JOB_OUT_DEFAULT = 220
export const JobOut = {
  mounted() {
    // What each pane's own grip was left at, by name. A pane that was
    // never dragged is not in here at all and takes the default from
    // the stylesheet — which is also what a double-click gives back.
    let tall = {}
    try { tall = JSON.parse(store.get(JOB_OUT_KEY) || "{}") || {} } catch (_) { tall = {} }

    const panes = () => {
      const all = [...this.el.querySelectorAll("[data-tall]")]
      return this.el.matches("[data-tall]") ? [this.el, ...all] : all
    }
    const cap = () => Math.max(JOB_OUT_MIN, Math.round(innerHeight * 0.8))
    // The cap is the pane's inside the box: the strip of controls under it is the box's own height, not the reader's.
    const height = pane => parseInt(getComputedStyle(pane.querySelector(".out .pane")).maxHeight, 10) || JOB_OUT_DEFAULT
    // Where a drag starts from: the box as drawn, not its cap. The cap
    // is a ceiling a short output never reaches, and a drag that began
    // there moved nothing until the hand had crossed the whole box —
    // past its foot in the tray, past its head on the Jobs screen.
    const drawn = pane => pane.querySelector(".out .pane").getBoundingClientRect().height || height(pane)
    const label = (pane, h) => {
      const g = pane.querySelector(".ograb")
      if (!g) return
      g.setAttribute("aria-valuenow", String(h))
      g.setAttribute("aria-valuemin", String(JOB_OUT_MIN))
      g.setAttribute("aria-valuemax", String(cap()))
      g.title = `${h}px — drag, or arrow keys; double-click for the default`
    }
    const set = (pane, px) => {
      const h = Math.round(Math.min(cap(), Math.max(JOB_OUT_MIN, px)))
      tall[pane.dataset.tall] = h
      pane.style.setProperty("--job-out", h + "px")
      label(pane, h)
      return h
    }
    const forget = pane => {
      delete tall[pane.dataset.tall]
      pane.style.removeProperty("--job-out")
      label(pane, height(pane))
    }
    const keep = () => store.set(JOB_OUT_KEY, JSON.stringify(tall))

    // A patch wipes the inline variable, so it is written again — and
    // this is also where a job that has left the list is forgotten. A
    // job's name is its id, a number; a named pane keeps its height.
    this.paint = () => {
      const live = {}
      for (const name in tall) if (!/^\d+$/.test(name)) live[name] = tall[name]
      for (const pane of panes()) {
        const name = pane.dataset.tall
        if (name in tall) {
          live[name] = tall[name]
          pane.style.setProperty("--job-out", tall[name] + "px")
        }
        label(pane, height(pane))
      }
      tall = live
    }
    this.paint()

    // Delegated: every open pane carries a grip, and each moves its own.
    this.el.addEventListener("pointerdown", ev => {
      const grip = ev.target.closest(".ograb")
      if (!grip) return
      const pane = grip.closest("[data-tall]")
      ev.preventDefault()
      grip.setPointerCapture(ev.pointerId)
      grip.classList.add("dragging")
      // A pane whose grip is above it grows the other way: the edge
      // under the hand is its top, so up is taller (the tray).
      const upward = pane.dataset.grip === "up"
      const from = upward ? drawn(pane) + ev.clientY : drawn(pane) - ev.clientY
      const move = e => set(pane, upward ? from - e.clientY : e.clientY + from)
      const up = () => {
        grip.classList.remove("dragging")
        grip.removeEventListener("pointermove", move)
        grip.removeEventListener("pointerup", up)
        grip.removeEventListener("pointercancel", up)
        keep()
      }
      grip.addEventListener("pointermove", move)
      grip.addEventListener("pointerup", up)
      grip.addEventListener("pointercancel", up)
    })

    this.el.addEventListener("dblclick", ev => {
      const grip = ev.target.closest(".ograb")
      if (!grip) return
      forget(grip.closest("[data-tall]")); keep()
    })

    this.el.addEventListener("keydown", ev => {
      const grip = ev.target.closest(".ograb")
      if (!grip) return
      const pane = grip.closest("[data-tall]"), step = ev.shiftKey ? 48 : 16
      const up = pane.dataset.grip === "up" ? 1 : -1
      if (ev.key === "ArrowUp") set(pane, drawn(pane) + up * step)
      else if (ev.key === "ArrowDown") set(pane, drawn(pane) - up * step)
      else if (ev.key === "Home") forget(pane)
      else return
      ev.preventDefault(); keep()
    })

    // A narrower window lowers the ceiling; what was over it comes down.
    this.resize = () => {
      for (const pane of panes()) {
        if (pane.dataset.tall in tall) set(pane, tall[pane.dataset.tall])
      }
    }
    addEventListener("resize", this.resize)
  },
  updated() { this.paint && this.paint() },
  destroyed() { removeEventListener("resize", this.resize) },
}

// --- a job's output, straight from Console.Jobs: the backlog once, on
// mount, then each batch as it is broadcast. Every batch says where it
// starts, so what arrived before the backlog answered is not written
// twice, and a batch that starts past what is here means a gap — the
// backlog is asked again. The element is phx-update="ignore": the
// server's patches never touch what is written here.
const JOB_LINES_CAP = 2000
export const JobLines = {
  mounted() {
    const el = this.el, id = el.dataset.job
    this.have = 0
    const add = (from, lines) => {
      if (from > this.have) return backlog()
      const rest = lines.slice(this.have - from)
      if (!rest.length) return
      const box = el.closest(".pane") || el.closest(".out") || el
      const atEnd = box.scrollHeight - box.scrollTop - box.clientHeight < 24
      const frag = document.createDocumentFragment()
      for (const html of rest) { const d = document.createElement("div"); d.innerHTML = html; frag.appendChild(d) }
      el.appendChild(frag)
      this.have = from + lines.length
      while (el.childElementCount > JOB_LINES_CAP) el.firstElementChild.remove()
      if (atEnd) box.scrollTop = box.scrollHeight
    }
    const backlog = () => this.pushEvent("job_backlog", { id }, ({ from, lines }) => { el.replaceChildren(); this.have = from; add(from, lines) })
    this.handleEvent("job_lines", ({ id: of, from, lines }) => { if (of === id) add(from, lines) })
    backlog()
  },
}

// --- which sections of the rail are folded. The fold itself is the
// server's — a class put on a section here is wiped by the next status —
// so this is only its memory: what came back, saved; what was saved,
// handed over on mount.
const FOLDS_KEY = "wb-console-folds"
export const Folds = {
  mounted() {
    const saved = store.get(FOLDS_KEY)
    if (saved) { try { const keys = JSON.parse(saved); if (Array.isArray(keys) && keys.length) this.pushEvent("folds_restore", { keys }) } catch (e) {} }
    this.handleEvent("folds", ({ keys }) => store.set(FOLDS_KEY, JSON.stringify(keys)))
  },
}

// --- a url field: the scheme written for you, and our own complaint -------------
// An option declared `:url` (formats/0) is refused without a scheme, and
// typing "https://" is the part nobody wants to type. The field opens
// with it and takes it back when nothing else was written, so a reader
// who tabs through leaves no half-address behind. Neither move is sent:
// the server hears the field when a key is pressed, and "https://"
// alone is not an answer. A pasted address that brings its own scheme
// replaces the one waiting instead of doubling it.
//
// The complaint is ours too. Left to the browser it is the browser's
// sentence in the browser's language ("Introduce una URL" on a Spanish
// one), which says neither what shape is wanted nor that the installer
// takes two schemes and no others; `setCustomValidity` replaces it with
// the rule the insert will hold the value to, in the console's language.
const SCHEME = /^https?:\/\//i
const ADDRESS = /^https?:\/\/[^\s"']+$/i
const SAYS =
  "This is a full address, scheme and all — http://example.com or https://example.com/page. " +
  "Only http:// and https:// are taken, and the rest cannot carry spaces or quotes."
const PREFIX = "https://"
export const UrlField = {
  mounted() {
    const el = this.el
    // Empty is unasked, and what unasked means is the cartridge's: the
    // field complains about what is written, never about nothing.
    const judge = () => el.setCustomValidity(el.value === "" || ADDRESS.test(el.value) ? "" : SAYS)

    // The scheme is written on focus, and the caret belongs after it.
    // A click places its own caret where the pointer landed — after the
    // focus event, so between the characters just written, and the next
    // keystroke would land inside "https://". `fresh` is that moment
    // and nothing else: while it lasts the caret is put back at the end
    // (on the frame after, so the click's own placing is already done),
    // and the first keystroke or a blur ends it, so a reader editing
    // what they wrote is never pushed around.
    let fresh = false
    const end = () => { if (fresh) el.setSelectionRange(el.value.length, el.value.length) }

    el.addEventListener("focus", () => {
      if (el.value === "") { el.value = PREFIX; fresh = true }
      if (fresh) requestAnimationFrame(end)
      judge()
    })

    el.addEventListener("mouseup", () => { if (fresh) requestAnimationFrame(end) })

    el.addEventListener("blur", () => {
      fresh = false
      if (SCHEME.test(el.value) && el.value.replace(SCHEME, "") === "") el.value = ""
      judge()
    })

    el.addEventListener("input", () => {
      fresh = false
      const doubled = el.value.match(/^https?:\/\/(https?:\/\/.*)$/i)
      if (doubled) { el.value = doubled[1]; el.setSelectionRange(el.value.length, el.value.length) }
      judge()
    })

    judge()
  },
}

// --- the rail's width: dragged, nudged with the arrows, reset with a double click, kept
const RAIL_KEY = "wb-console-rail", RAIL_MIN = 300, RAIL_MAX_SHARE = 0.5, RAIL_DEFAULT = 500
export const Rail = {
  mounted() {
    const app = this.el, grip = app.querySelector("#rail-grip")
    const setRail = px => {
      const max = Math.max(RAIL_MIN, Math.round(innerWidth * RAIL_MAX_SHARE))
      const w = Math.round(Math.min(max, Math.max(RAIL_MIN, px)))
      // On :root and not on the element this hook rides. #app is the
      // LiveView's, and a patch anywhere inside it walks its attributes
      // and drops what the server did not render — the width went back
      // to the stylesheet's 380px the first time a section of the rail
      // was folded. The same lesson the fold itself taught: what the
      // client decides must not be written where the server renders.
      document.documentElement.style.setProperty("--rail-set", w + "px")
      grip.setAttribute("aria-valuenow", String(w)); grip.setAttribute("aria-valuemin", String(RAIL_MIN)); grip.setAttribute("aria-valuemax", String(max))
      grip.title = `${w}px — drag, or arrow keys; double-click for ${RAIL_DEFAULT}`
      return w
    }
    const width = () => parseInt(getComputedStyle(app).getPropertyValue("--rail"), 10) || RAIL_DEFAULT
    // The grip's own attributes are inside the patched tree too, so they
    // are written again after one; the width itself no longer needs to be.
    this.again = () => setRail(width())
    const fromPointer = ev => document.body.classList.contains("rail-right") ? innerWidth - ev.clientX : ev.clientX
    grip.addEventListener("pointerdown", ev => {
      ev.preventDefault(); grip.setPointerCapture(ev.pointerId); grip.classList.add("dragging")
      const offset = width() - fromPointer(ev)
      const move = e => setRail(fromPointer(e) + offset)
      const up = () => { grip.classList.remove("dragging"); grip.removeEventListener("pointermove", move); grip.removeEventListener("pointerup", up); grip.removeEventListener("pointercancel", up); store.set(RAIL_KEY, String(width())) }
      grip.addEventListener("pointermove", move); grip.addEventListener("pointerup", up); grip.addEventListener("pointercancel", up)
    })
    grip.addEventListener("dblclick", () => { setRail(RAIL_DEFAULT); store.set(RAIL_KEY, String(RAIL_DEFAULT)) })
    grip.addEventListener("keydown", ev => {
      const step = ev.shiftKey ? 48 : 16, right = document.body.classList.contains("rail-right")
      let w = null
      if (ev.key === "ArrowLeft") w = width() + (right ? step : -step)
      if (ev.key === "ArrowRight") w = width() + (right ? -step : step)
      if (ev.key === "Home") w = RAIL_DEFAULT
      if (w === null) return
      ev.preventDefault(); setRail(w); store.set(RAIL_KEY, String(width()))
    })
    this.resize = this.again
    addEventListener("resize", this.resize)
    // The rail's two squares, the way hexdocs folds its sidebar: Left
    // and Right, each the frame it would set. Pressing the other side
    // moves the rail; pressing the side it is on puts it away, and
    // either brings it back on its own side. They are the Interface
    // tab's Left, Right and Hidden, kept the same way, and painted from
    // the body so the two agree whichever one was pressed.
    const rail = document.getElementById("rail")
    // The gutter the rail keeps for its scrollbar, which its right padding
    // gives back so the air reads 22px on both sides. Written on the
    // root, as the width is, and never on the app: LiveView patches the
    // app, and a patch drops the inline style the server never wrote —
    // the rail's air grew 15px on every compose file opened under its
    // row, until 2026-09-15 — and `updated` is not to be counted on to
    // write it again.
    const gutter = () => {
      if (!rail) return
      const cs = getComputedStyle(rail)
      const g = rail.offsetWidth - rail.clientWidth - parseFloat(cs.borderLeftWidth) - parseFloat(cs.borderRightWidth)
      document.documentElement.style.setProperty("--rail-gutter", Math.max(0, g) + "px")
    }
    const squares = { left: document.getElementById("rail-left"), right: document.getElementById("rail-right") }
    const paintToggle = () => {
      gutter()
      const off = document.body.classList.contains("rail-off"), on = document.body.classList.contains("rail-right") ? "right" : "left"
      for (const [side, sq] of Object.entries(squares)) {
        if (!sq) continue
        const pressed = !off && side === on
        sq.setAttribute("aria-pressed", String(pressed))
        sq.title = pressed ? "put the rail away" : off ? `bring the rail back, on the ${side}` : `move the rail to the ${side}`
      }
    }
    const keepFrame = () => store.set("wb-console-frame", JSON.stringify(FRAME_CLASSES.filter(c => document.body.classList.contains(c))))
    const put = side => {
      const off = document.body.classList.contains("rail-off"), on = document.body.classList.contains("rail-right") ? "right" : "left"
      if (!off && side === on) document.body.classList.add("rail-off")
      else { document.body.classList.remove("rail-off"); document.body.classList.toggle("rail-right", side === "right") }
      keepFrame(); paintToggle(); dispatchEvent(new Event("resize"))
    }
    squares.left?.addEventListener("click", () => put("left"))
    squares.right?.addEventListener("click", () => put("right"))
    this.paintToggle = paintToggle; addEventListener("resize", paintToggle)
    const saved = store.get(RAIL_KEY)
    setRail(saved ? +saved : RAIL_DEFAULT)
    // The frame the reader chose — the band's side, the rail's — as classes on <body>.
    try { for (const cls of JSON.parse(store.get("wb-console-frame") || "[]")) document.body.classList.add(cls) } catch (e) {}
    paintToggle()
  },
  updated() { this.again && this.again(); this.paintToggle && this.paintToggle() },
  destroyed() { removeEventListener("resize", this.resize); removeEventListener("resize", this.paintToggle) },
}

// --- the logs: the server pushes lines, the hook keeps and filters them ------
// Two thousand lines and a search box: filtering on the server would
// re-render them all across the socket on every keystroke.
// A service's colour is its role's, and what a service is its cartridge
// says: the server knows (ConsoleWeb.Services) and leaves the answer on
// #svc-colors, by name. A service it has not heard of wears the plainest.
const svcColor = s => {
  const base = /^app\d+$/.test(s) ? "app" : s
  let known = {}
  try { known = JSON.parse(document.getElementById("svc-colors")?.dataset.colors || "{}") } catch (_) {}
  return known[base] || "var(--svc-network)"
}
function levelOf(text) {
  if (/^\s*\[error\]|ERROR:|FATAL:|\*\* \(|CRITICAL|\berror\b.*\bfailed\b/i.test(text)) return "error"
  if (/^\s*\[warning\]|WARNING:|warning:|HINT:/.test(text)) return "warn"
  if (/^\s*\[info\]|LOG:|^\S+ - - \[/.test(text)) return "info"
  if (/^\s*\[debug\]/.test(text)) return "debug"
  return "info"
}
const fmtTs = iso => { const d = new Date(iso); return isNaN(d) ? "" : d.toTimeString().slice(0, 8) + "." + String(d.getMilliseconds()).padStart(3, "0") }
const h = (tag, cls, text) => { const n = document.createElement(tag); if (cls) n.className = cls; if (text !== undefined) n.textContent = text; return n }

export const Logs = {
  mounted() {
    const el = this.el, $ = s => el.querySelector(s)
    const logs = { all: [], follow: true, ts: true, level: "debug", q: "", services: {}, unseenErrors: 0, pending: 0, cap: 2000 }
    const box = $("#lines"), rank = { debug: 0, info: 1, warn: 2, error: 3 }
    const badge = document.getElementById("logs-badge")
    const onScreen = () => location.pathname.replace(/\/$/, "").endsWith("/logs")
    const passes = l => !(logs.services[l.service] === false) && rank[l.level] >= rank[logs.level] && (!logs.q || l.text.toLowerCase().includes(logs.q.toLowerCase()))
    // The line's own colours (the ansi cartridge's) are spans in `html`,
    // from the server; a search writes the plain text with its mark
    // instead, since the match is found on the text.
    const lineEl = l => {
      const m = h("span", "m")
      if (logs.q) { const i = l.text.toLowerCase().indexOf(logs.q.toLowerCase()); if (i >= 0) { m.append(l.text.slice(0, i), Object.assign(h("mark"), { textContent: l.text.slice(i, i + logs.q.length) }), l.text.slice(i + logs.q.length)) } else m.textContent = l.text }
      else m.innerHTML = l.html
      const n = h("div", "ln " + l.level + (l.cont ? " cont" : "") + (logs.q ? " hit" : ""))
      n.style.setProperty("--svc", svcColor(l.service))
      n.append(h("span", "t", fmtTs(l.ts)), h("span", "s", l.service), m)
      return n
    }
    const renderCount = () => { const vis = logs.all.filter(passes).length; $("#log-count").textContent = `${vis} of ${logs.all.length} lines` + (logs.q ? ` matching “${logs.q}”` : "") }
    // The unseen errors are the client's to count; the pulse beside them
    // is not the client's to decide — it says a container is running,
    // which only the status knows.
    const renderBadge = () => { if (badge) { badge.hidden = !logs.unseenErrors; badge.textContent = logs.unseenErrors + " err" } }
    const scrollToEnd = () => { box.scrollTop = box.scrollHeight; logs.pending = 0; $("#newpill").classList.remove("on") }
    const setFollow = on => { logs.follow = on; $("#follow").setAttribute("aria-pressed", String(on)); $("#follow").textContent = on ? "Following" : "Paused"; if (on) scrollToEnd(); renderBadge() }
    // A service's mark, the rack of the sprite, as the server draws it on the Terminal's buttons (ConsoleWeb.Square.mark): its colour is the service's, --svc.
    const SVC_MARK = '<svg class="mark" aria-hidden="true"><use href="/images/icons.svg#rack"></use></svg>'
    const renderChips = () => {
      const chips = $("#svc-chips"); chips.replaceChildren()
      // The service column is the longest name wide, so every message starts in one column and the gap after the longest is the grid's.
      const names = Object.keys(logs.services); box.style.setProperty("--svc-w", `${Math.max(1, ...names.map(s => s.length))}ch`)
      for (const s of Object.keys(logs.services)) {
        const b = h("button", "btn svc", s); b.type = "button"; b.style.setProperty("--svc", svcColor(s)); b.insertAdjacentHTML("afterbegin", SVC_MARK); b.setAttribute("aria-pressed", String(logs.services[s] !== false))
        b.addEventListener("click", () => { logs.services[s] = !(logs.services[s] !== false); b.setAttribute("aria-pressed", String(logs.services[s])); rerender() })
        chips.append(b)
      }
    }
    const rerender = () => {
      box.replaceChildren()
      box.classList.toggle("no-svc", Object.keys(logs.services).filter(s => logs.services[s] !== false).length === 1)
      const vis = logs.all.filter(passes)
      for (const l of vis) box.append(lineEl(l))
      // An empty box says nothing; only a filter that leaves nothing says so.
      if (!vis.length && logs.all.length) box.append(h("div", "nothing", "Nothing matches: every line is filtered out."))
      if (logs.follow) scrollToEnd()
      renderCount()
    }
    const append = l => {
      const atEnd = box.scrollHeight - box.scrollTop - box.clientHeight < 24
      box.append(lineEl(l))
      while (box.children.length > logs.cap) box.firstChild.remove()
      if (logs.follow && atEnd) box.scrollTop = box.scrollHeight
      else { if (logs.follow) setFollow(false); logs.pending++; $("#newpill").classList.add("on"); $("#newpill").textContent = `↓ ${logs.pending} new line${logs.pending === 1 ? "" : "s"}` }
    }
    const push = (l, quiet) => {
      const prev = logs.all[logs.all.length - 1]
      const cont = !!prev && prev.service === l.service && /^\s/.test(l.text)
      const line = { ...l, level: cont ? prev.level : levelOf(l.text), cont }
      logs.all.push(line); if (logs.all.length > logs.cap) logs.all.shift()
      if (!(l.service in logs.services)) { logs.services[l.service] = true; renderChips() }
      if (line.level === "error" && !onScreen() && !quiet) { logs.unseenErrors++; renderBadge() }
      if (!quiet) { if (passes(line)) append(line); renderCount() }
    }
    $("#level").addEventListener("change", ev => { logs.level = ev.target.value; rerender() })
    $("#q").addEventListener("input", ev => { logs.q = ev.target.value.trim(); rerender() })
    $("#follow").addEventListener("click", () => setFollow(!logs.follow))
    $("#ts").addEventListener("click", () => { logs.ts = !logs.ts; $("#ts").setAttribute("aria-pressed", String(logs.ts)); box.classList.toggle("no-ts", !logs.ts) })
    $("#clear").addEventListener("click", () => { logs.all = []; rerender() })
    $("#newpill").addEventListener("click", () => setFollow(true))
    box.addEventListener("scroll", () => { if (box.scrollHeight - box.scrollTop - box.clientHeight < 24 && logs.pending) { logs.pending = 0; $("#newpill").classList.remove("on") } })
    // Arriving on the screen: what was unseen is seen.
    window.addEventListener("phx:page-loading-stop", () => { if (onScreen()) { logs.unseenErrors = 0; renderBadge(); if (logs.follow) scrollToEnd() } })
    // One container's lines, asked for from its row in the rail: that
    // service is the only one lit, and every other chip goes off. A
    // service with no lines yet has no chip, so it is written into the
    // set first — otherwise asking for the quiet one would show them all.
    this.handleEvent("logs_only", ({ service }) => {
      if (!(service in logs.services)) logs.services[service] = true
      for (const s of Object.keys(logs.services)) logs.services[s] = s === service
      renderChips(); rerender()
    })
    this.handleEvent("log", l => push(l))
    // The lines the stream already holds; a stream started again starts the page over too.
    this.pushEvent("logs_backlog", {}, ({ lines }) => { logs.all = []; for (const l of lines) push(l, true); rerender() })
    this.handleEvent("logs_restarted", () => { this.pushEvent("logs_backlog", {}, ({ lines }) => { logs.all = []; logs.services = {}; renderChips(); for (const l of lines) push(l, true); rerender() }) })
    rerender(); renderBadge()
  },
}

// --- the booklet: a paper's in-console links go through the socket, and
// the index scrolls the drawer, not the page.
export const Booklet = {
  // Every figure gets the expand hint and opens the viewer. Done on
  // mount and on every patch: the booklet is one element for every
  // paper of a box, so turning from the README to the DESIGN brings
  // new figures into the same element, and a figure only met on mount
  // stayed a bare image — no hint, no viewer. Idempotent, so a patch
  // that leaves the figures alone changes nothing.
  figures() {
    for (const img of this.el.querySelectorAll("article.md img")) {
      if (img.closest(".fig")) continue
      const wrap = document.createElement("figure"); wrap.className = "fig"
      img.replaceWith(wrap); const hint = document.createElement("span"); hint.className = "expand"; hint.textContent = "⤢ expand"; wrap.append(img, hint)
      wrap.addEventListener("click", () => openViewer(img, img.alt || "Figure"))
    }
  },
  updated() { this.figures() },
  mounted() {
    this.figures()
    this.el.addEventListener("click", ev => {
      const a = ev.target.closest("a"); if (!a) return
      if (a.hasAttribute("data-patch")) { ev.preventDefault(); this.pushEvent("goto", { href: a.getAttribute("href") }) }
      else if (a.getAttribute("href")?.startsWith("#")) { ev.preventDefault(); this.go(a.getAttribute("href").slice(1), true) }
    })
    // Opened on a link with a section in it: land on the section.
    if (location.hash.length > 1) this.go(decodeURIComponent(location.hash.slice(1)), false)
  },
  // The heading ids are the paper's own, GitHub's for its words, so two
  // papers on the page — a box's manual under the drawer's — can share
  // one: this booklet's article is searched first, the document after.
  // The section goes in the address, so the link can be copied; the
  // history entry stays LiveView's.
  go(id, keep) {
    const target = id === "top" ? this.el.querySelector(".md") : (this.el.querySelector(`[id="${CSS.escape(id)}"]`) || document.getElementById(id))
    if (!target) return
    target.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "start" })
    if (keep) history.replaceState(history.state, "", id === "top" ? location.pathname + location.search : `#${id}`)
  },
}

// --- the box in hand: a click turns it (phx-click on the face; Enter is
// phx-keydown, Space is the browser's own for a button and is given here),
// and the lozenge in its corner opens the viewer on the piece — both faces
// side by side, centred on the side that shows.
// The lozenge stops its click before the document, where LiveView listens
// for the face's.
export const Face = {
  mounted() {
    this.el.addEventListener("keydown", ev => { if (ev.key === " " && ev.target === this.el) { ev.preventDefault(); this.el.click() } })
    this.el.querySelector(".expand").addEventListener("click", ev => {
      ev.stopPropagation()
      // The viewer is given the piece, both faces, and the side that showed:
      // it opens on that one and holds the other beside it.
      const back = this.el.querySelector(".cover").classList.contains("back")
      const front = this.el.querySelector(".side.front img"), rear = this.el.querySelector(".side.back img")
      if (front && rear) openViewerPair([front, rear], (front.alt || rear.alt || "The box").replace(/ — box (cover|back)$/, ""), ["cover", "back"], back ? 1 : 0)
      else { const img = back ? rear : front; if (img) openViewer(img, img.alt || (back ? "The back of the box" : "The box")) }
    })
  },
}

// --- which shape the shelf takes is the reader's: remembered here, pushed on arrival.
export const ShelfView = {
  mounted() {
    const saved = store.get("wb-console-shelf")
    if (saved === "list" || saved === "covers") this.pushEvent("view", { view: saved })
    this.el.addEventListener("click", ev => { const b = ev.target.closest("button[phx-value-view]"); if (b) store.set("wb-console-shelf", b.getAttribute("phx-value-view")) })
  },
}

// --- the frame: where the band sits, which side the rail is on, whether it is there.
// Three independent switches, each one class on <body>, each drawn by the
// button that flips it — the icon is a map of the page.
const FRAME_CLASSES = ["band-bottom", "rail-right", "rail-off"]
// What each segment sets: the band's two, the rail's three — hidden is
// a position of the rail, not a setting of its own, and it keeps the side.
const PICKS = {
  top: { bottom: false }, bottom: { bottom: true },
  left: { right: false, off: false }, right: { right: true, off: false }, hidden: { off: true },
}
// --- the code and the files: the face, size and leading of two kinds of
// surface, chosen in the drawer and kept in this browser. `code` is what
// runs — the terminals, the jobs' output, the logs, Docker's events;
// `file` is what is read — the Files sheet, the diffs, .env and
// config.conf, the papers' code blocks. Each is three custom properties
// on the root, `--<group>-face`, `--<group>-size` and `--<group>-leading`,
// that every surface of the group reads with its own default in the
// fallback — so the page's own mono is the properties absent, and each
// surface keeps the size and leading it was drawn at. A reader who has
// chosen nothing gets the house's (DEFAULTS, below). A face brings its sizes:
// Tamzen and Greybeard are bitmap faces, one drawing per size, and the
// drawing is the family name; the vector faces take any. The leading is unitless, a
// ratio of the size, so it holds when the size changes.
const GROUPS = { code: "wb-console-code", file: "wb-console-file" }
const SIZES = [10, 11, 12, 13, 14, 15, 16, 18, 20]
const LEADINGS = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2]
const FACES = {
  house: { name: "IBM Plex Mono", sizes: SIZES, family: () => null },
  fira: { name: "Fira Code", sizes: SIZES, family: () => '"Fira Code"', note: "Ligatures on.", blocks: true },
  vga: { name: "Flexi IBM VGA", sizes: [14, 16, 18, 20, 24, 32], family: () => '"Flexi IBM VGA True"', note: "The PC's text mode, a bitmap: its own sizes.", bitmap: true, blocks: true },
  tamzen: { name: "Tamzen", sizes: [9, 12, 13, 14, 15, 16, 20], family: s => `"Tamzen${{ 9: 5, 12: 6, 13: 7, 14: 7, 15: 8, 16: 8, 20: 10 }[s]}x${s}"`, note: "A bitmap face, one drawing a size.", bitmap: true },
  greybeard: { name: "Greybeard", sizes: [11, 12, 13, 14, 15, 16, 17, 18, 22], family: s => `"Greybeard${{ 11: 6, 12: 6, 13: 7, 14: 7, 15: 8, 16: 8, 17: 9, 18: 9, 22: 11 }[s]}x${s}"`, note: "A bitmap face, one drawing a size; it draws the boxes, the blocks and the shades.", bitmap: true, blocks: true },
}
// (Whose each face is, and under which licence, the drawer's Faces part says: the notes above say what a face does.)
// The pages' own type — the display, the text and the mono, and a scale
// of the whole — was the Text part until 2026-09-30, kept as
// wb-console-text. It is retired for now, the rest of the interface not
// being offered to customise yet, and what it kept is forgotten: a face
// nobody can change any more must not stay on.
try { localStorage.removeItem("wb-console-text") } catch (e) {}
const usual = f => f.sizes[Math.floor(f.sizes.length / 2)]
// The house's, for a reader who has kept no choice (2026-10-01): what runs
// in Tamzen at 15 px, a line on the next, and what is read in Fira Code at
// 13 px and 1.2. Until then it was the page's own mono, IBM Plex — the
// face `house`, still on the list — at each surface's drawn size. A
// choice once kept is the reader's and stays, that one included.
const DEFAULTS = { code: { face: "tamzen", size: 15, leading: 1 }, file: { face: "fira", size: 13, leading: 1.2 } }
const cleanChoice = c => ({ face: c?.face in FACES ? c.face : "house", size: Number(c?.size) || null, leading: LEADINGS.includes(c?.leading) ? c.leading : null })
const choiceOf = group => { try { const kept = store.get(GROUPS[group]); return kept ? cleanChoice(JSON.parse(kept)) : { ...DEFAULTS[group] } } catch (e) { return { ...DEFAULTS[group] } } }
function applyChoice(group, { face, size, leading }) {
  const root = document.documentElement.style, f = FACES[face]
  const s = f.sizes.includes(size) ? size : (face === "house" ? null : usual(f))
  const family = f.family(s || usual(f))
  if (family) root.setProperty(`--${group}-face`, family); else root.removeProperty(`--${group}-face`)
  if (s) root.setProperty(`--${group}-size`, `${s}px`); else root.removeProperty(`--${group}-size`)
  if (leading) root.setProperty(`--${group}-leading`, String(leading)); else root.removeProperty(`--${group}-leading`)
  // A bitmap face has one drawing per size: the sheet's line numbers, drawn smaller than the code in a vector face, keep the code's size in it or they blur.
  if (f.bitmap) root.setProperty(`--${group}-ruler`, "1"); else root.removeProperty(`--${group}-ruler`)
  // A face that draws the blocks and the shades itself (`blocks`) says so on the root, and the miniature's colour scale is then left in it; without the mark the scale is set in a stand-in (console.css, .scale).
  document.documentElement.toggleAttribute(`data-${group}-blocks`, !!f.blocks)
  return { face, size: s, leading: leading || null }
}
for (const g of Object.keys(GROUPS)) applyChoice(g, choiceOf(g))
// The three selects of one group: the face fills the size's options
// with its own, and any change is applied at once and kept.
function bindPicks(el, group) {
  const faceSel = el.querySelector(`#${group}-face`), sizeSel = el.querySelector(`#${group}-size`), leadSel = el.querySelector(`#${group}-leading`), note = el.querySelector(`#help-${group}`)
  if (!faceSel || !sizeSel || !leadSel) return
  let choice = choiceOf(group)
  const opt = (v, text, on) => { const o = document.createElement("option"); o.value = v; o.textContent = text; o.selected = on; return o }
  const draw = () => {
    const f = FACES[choice.face]
    faceSel.replaceChildren(...Object.entries(FACES).map(([k, v]) => opt(k, v.name, k === choice.face)))
    // A size and a leading are chosen, never "as drawn" (2026-09-30): the page's mono's are shown as what they are, 12 px and 1.5 — the
    // surfaces drawn at 12.5 or 1.6 keep theirs while nothing is chosen, and take the number the moment one is.
    sizeSel.replaceChildren(...f.sizes.map(n => opt(n, `${n} px`, n === (choice.size || (f.sizes.includes(12) ? 12 : usual(f))))))
    leadSel.replaceChildren(...LEADINGS.map(n => opt(n, n.toFixed(1), n === (choice.leading || 1.5))))
    if (note) note.textContent = f.note || ""
  }
  // The face is the reader's, no theme's (2026-09-30): choosing one touches no shelf.
  const keep = () => { choice = applyChoice(group, choice); store.set(GROUPS[group], JSON.stringify(choice)); draw() }
  faceSel.addEventListener("change", () => { choice = { ...choice, face: faceSel.value, size: null }; keep() })
  sizeSel.addEventListener("change", () => { choice = { ...choice, size: sizeSel.value ? Number(sizeSel.value) : null }; keep() })
  leadSel.addEventListener("change", () => { choice = { ...choice, leading: leadSel.value ? Number(leadSel.value) : null }; keep() })
  draw()
  // For a theme: the choice as it is, and the choice set whole (a bare one is the house's).
  return { get: () => choice, replace: c => { choice = c?.face ? cleanChoice(c) : { ...DEFAULTS[group] }; keep() } }
}

// --- the colours: twelve rules, One Dark's for Elixir as they were
// written in a VS Code jsonc (console/elixir_color_theme.jsonc until
// 2026-09-29, archived out of git in _archived/ once they were carried
// here whole, with One Light's, and themes/default.code.json is that file
// again in the shelf's form), each a property on the root the `.src` surfaces read, kept in this
// browser like the faces — one palette a ground, because a colour that
// reads on the dark terminal is lost on paper, and one a language,
// because JSON's keys and Elixir's modules share a class and not a
// meaning. A language names only the rules it has: JSON has no keywords.
// The scopes are the language's own in VS Code's grammars, so a theme
// pastes in — each rule matched to the roles by scope, as an editor
// matches them: equal, or a parent of it, and a scope with no language
// reaches every language that lists one under it — and reads back out
// in the same shape, every language at once, to carry to VS Code.
const COLOURS_KEY = "wb-console-colours"
const KEYS = ["base", "punct", "comment", "atom", "const", "func", "kw", "op", "mod", "str", "interp", "regex"]
const LANGS = {
  elixir: { name: "Elixir and its templates", roles: [
    { key: "base", name: "code", scopes: ["source.elixir"] },
    { key: "punct", name: "brackets", scopes: ["punctuation.section.scope.elixir", "punctuation.section.array.elixir", "punctuation.section.function.elixir", "punctuation.section.list.begin.elixir", "punctuation.section.list.end.elixir"] },
    { key: "comment", name: "comments", scopes: ["punctuation.definition.comment.elixir", "comment.line.number-sign.elixir", "comment.unused.elixir", "comment.documentation.heredoc.elixir"], style: "italic" },
    { key: "atom", name: "atoms", scopes: ["constant.character.escape.elixir", "constant.other.symbol.elixir"] },
    { key: "const", name: "constants", title: "constants, numbers", scopes: ["punctuation.definition.constant.elixir", "constant.language.elixir", "constant.numeric.elixir"] },
    { key: "func", name: "functions", scopes: ["entity.name.function.elixir"] },
    { key: "kw", name: "keywords", scopes: ["keyword.control.module.elixir", "keyword.control.elixir", "variable.other.anonymous.elixir"] },
    { key: "op", name: "operators", scopes: ["keyword.operator.other.elixir", "keyword.operator.assignment.elixir", "keyword.operator.logical.elixir", "keyword.operator.comparison.elixir", "keyword.operator.arithmetic.elixir", "punctuation.separator.object.elixir", "punctuation.separator.method.elixir", "parameter.variable.function.elixir"], italic: ["parameter.variable.function.elixir"] },
    { key: "mod", name: "modules", scopes: ["variable.other.constant.elixir", "entity.name.type.module.elixir"] },
    { key: "str", name: "strings", scopes: ["punctuation.definition.string.begin.elixir", "punctuation.definition.string.end.elixir", "string.quoted.double.elixir", "support.function.variable.quoted.single.elixir", "string.quoted.double.interpolated.elixir", "string.quoted.double.literal.elixir"] },
    { key: "interp", name: "embedded", scopes: ["punctuation.section.embedded.elixir", "keyword.other.special-method.elixir", "punctuation.definition.variable.elixir", "variable.other.readwrite.module.elixir", "variable.language.elixir"] },
    { key: "regex", name: "regex", scopes: ["punctuation.section.regexp.begin.elixir", "punctuation.section.regexp.end.elixir", "string.regexp.interpolated.elixir", "string.regexp.group.elixir", "string.regexp.character-class.elixir", "string.regexp.arbitrary-repitition.elixir"] },
  ] },
  html: { name: "HTML and its templates", roles: [
    { key: "base", name: "Elixir in a template", scopes: ["text.html.basic", "source.elixir.embedded.html"] },
    { key: "punct", name: "brackets, braces", scopes: ["punctuation.definition.tag.begin.html", "punctuation.definition.tag.end.html", "punctuation.section.embedded.begin.elixir", "punctuation.section.embedded.end.elixir"] },
    { key: "comment", name: "comments, doctype", scopes: ["comment.block.html", "meta.tag.metadata.doctype.html"], style: "italic" },
    { key: "mod", name: "tags", scopes: ["entity.name.tag.html"] },
    { key: "interp", name: "attributes, assigns", scopes: ["entity.other.attribute-name.html", "variable.other.readwrite.module.elixir"] },
    { key: "str", name: "values, text", scopes: ["string.quoted.double.html", "string.quoted.single.html"] },
    { key: "op", name: "equals, operators", scopes: ["punctuation.separator.key-value.html"] },
    { key: "const", name: "numbers", scopes: ["constant.numeric.elixir"] },
  ] },
  css: { name: "CSS and SCSS", roles: [
    { key: "base", name: "tag selectors, values", scopes: ["source.css", "entity.name.tag.css", "support.constant.property-value.css"] },
    { key: "punct", name: "braces, semicolons", scopes: ["punctuation.section.property-list.css", "punctuation.terminator.rule.css", "punctuation.separator.list.comma.css"] },
    { key: "comment", name: "comments", scopes: ["comment.block.css"], style: "italic" },
    { key: "atom", name: "ids, pseudo-classes, colours", scopes: ["entity.other.attribute-name.id.css", "entity.other.attribute-name.pseudo-class.css", "constant.other.color.rgb-value.hex.css"] },
    { key: "const", name: "numbers, units", scopes: ["constant.numeric.css", "keyword.other.unit.css"] },
    { key: "func", name: "functions", scopes: ["support.function.css", "support.function.misc.css"] },
    { key: "kw", name: "properties", scopes: ["support.type.property-name.css"] },
    { key: "op", name: "combinators, operators", scopes: ["keyword.operator.combinator.css", "keyword.operator.arithmetic.css"] },
    { key: "mod", name: "at-rules, !important", scopes: ["keyword.control.at-rule.css", "keyword.other.important.css"] },
    { key: "str", name: "strings", scopes: ["string.quoted.double.css", "string.quoted.single.css"] },
    { key: "interp", name: "class selectors", scopes: ["entity.other.attribute-name.class.css"] },
  ] },
  json: { name: "JSON", roles: [
    { key: "punct", name: "brackets, commas", scopes: ["punctuation.separator.dictionary.key-value.json", "punctuation.separator.dictionary.pair.json", "punctuation.separator.array.json", "punctuation.definition.dictionary.begin.json", "punctuation.definition.dictionary.end.json", "punctuation.definition.array.begin.json", "punctuation.definition.array.end.json"] },
    { key: "comment", name: "comments", scopes: ["comment.block.json", "comment.line.double-slash.json"], style: "italic" },
    { key: "const", name: "numbers, true, false, null", scopes: ["constant.numeric.json", "constant.language.json"] },
    { key: "mod", name: "keys", scopes: ["support.type.property-name.json"] },
    { key: "str", name: "strings", scopes: ["string.quoted.double.json"] },
  ] },
  ts: { name: "TypeScript and JavaScript", roles: [
    { key: "base", name: "names", scopes: ["source.ts", "variable.other.readwrite.ts"] },
    { key: "punct", name: "brackets", scopes: ["punctuation.definition.block.ts", "meta.brace.round.ts", "meta.brace.square.ts", "punctuation.terminator.statement.ts"] },
    { key: "comment", name: "comments", scopes: ["comment.line.double-slash.ts", "comment.block.ts", "comment.block.documentation.ts"], style: "italic" },
    { key: "const", name: "numbers", scopes: ["constant.numeric.ts", "constant.language.ts"] },
    { key: "func", name: "functions", scopes: ["entity.name.function.ts", "support.function.ts"] },
    { key: "kw", name: "keywords", scopes: ["keyword.control.ts", "storage.type.ts", "storage.modifier.ts", "keyword.operator.new.ts", "variable.language.this.ts"] },
    { key: "op", name: "operators", scopes: ["keyword.operator.assignment.ts", "keyword.operator.arithmetic.ts", "keyword.operator.comparison.ts", "keyword.operator.logical.ts", "keyword.operator.ternary.ts"] },
    { key: "mod", name: "types, classes", scopes: ["entity.name.type.ts", "entity.name.type.class.ts", "support.type.primitive.ts", "support.class.ts"] },
    { key: "str", name: "strings", scopes: ["string.quoted.double.ts", "string.quoted.single.ts", "string.template.ts"] },
    { key: "interp", name: "template holes", scopes: ["punctuation.definition.template-expression.begin.ts", "punctuation.definition.template-expression.end.ts"] },
  ] },
  markdown: { name: "Markdown", roles: [
    { key: "base", name: "text", scopes: ["text.html.markdown"] },
    { key: "punct", name: "marks", scopes: ["punctuation.definition.markdown", "punctuation.definition.heading.markdown", "punctuation.definition.bold.markdown", "punctuation.definition.italic.markdown", "punctuation.definition.raw.markdown", "punctuation.definition.list.begin.markdown"] },
    { key: "const", name: "a fence's language", scopes: ["fenced_code.block.language.markdown"] },
    { key: "interp", name: "headings", scopes: ["markup.heading.markdown", "entity.name.section.markdown"] },
    { key: "op", name: "bold", scopes: ["markup.bold.markdown"] },
    { key: "kw", name: "italic", scopes: ["markup.italic.markdown"] },
    { key: "str", name: "code, links, lists, quotes", scopes: ["markup.inline.raw.string.markdown", "markup.fenced_code.block.markdown", "markup.underline.link.markdown", "markup.list.unnumbered.markdown", "markup.list.numbered.markdown", "markup.quote.markdown"] },
  ] },
  // GDScript's scopes are the godot-tools extension's; the shader's are
  // GLSL's, the scene's INI's — the three kinds of file share the palette.
  godot: { name: "Godot: GDScript, shaders, scenes", roles: [
    { key: "base", name: "names", scopes: ["source.gdscript", "variable.other.gdscript", "variable.parameter.function.gdscript"] },
    { key: "punct", name: "brackets", scopes: ["punctuation.definition.parameters.begin.gdscript", "punctuation.definition.parameters.end.gdscript", "punctuation.separator.parameters.gdscript"] },
    { key: "comment", name: "comments", scopes: ["comment.line.number-sign.gdscript", "comment.line.double-slash.glsl", "comment.block.glsl"], style: "italic" },
    { key: "const", name: "numbers", scopes: ["constant.numeric.gdscript", "constant.numeric.glsl"] },
    { key: "func", name: "functions", scopes: ["entity.name.function.gdscript", "support.function.builtin.gdscript", "support.function.glsl"] },
    { key: "kw", name: "keywords", scopes: ["keyword.control.gdscript", "keyword.language.gdscript", "keyword.control.glsl"] },
    { key: "op", name: "operators", scopes: ["keyword.operator.gdscript", "keyword.operator.wordlike.gdscript", "keyword.operator.glsl"] },
    { key: "mod", name: "var, const, func, signal, types", scopes: ["storage.type.gdscript", "storage.type.var.gdscript", "storage.type.const.gdscript", "storage.type.function.gdscript", "entity.other.inherited-class.gdscript", "entity.name.type.class.gdscript", "storage.type.glsl"] },
    { key: "str", name: "strings, scene values", scopes: ["string.quoted.double.gdscript", "string.quoted.single.gdscript", "string.quoted.double.ini"] },
    { key: "interp", name: "annotations, uniforms, scene keys", scopes: ["entity.name.function.decorator.gdscript", "storage.modifier.gdscript", "storage.type.qualifier.glsl", "keyword.other.definition.ini"] },
  ] },
  // The shell's scopes are VS Code's shellscript grammar's; a paper's
  // ` ```sh ` fence reads with them, through syntect's grammar.
  shell: { name: "Shell", roles: [
    { key: "base", name: "words, flags", scopes: ["source.shell", "variable.other.normal.shell"] },
    { key: "punct", name: "quotes, braces", scopes: ["punctuation.definition.string.begin.shell", "punctuation.definition.string.end.shell", "punctuation.definition.variable.shell", "meta.scope.group.shell"] },
    { key: "comment", name: "comments", scopes: ["comment.line.number-sign.shell", "comment.line.shebang.shell"], style: "italic" },
    { key: "const", name: "numbers", scopes: ["constant.numeric.shell"] },
    { key: "func", name: "commands", scopes: ["entity.name.command.shell", "support.function.builtin.shell", "entity.name.function.shell"] },
    { key: "kw", name: "if, for, case", scopes: ["keyword.control.shell", "storage.type.function.shell"] },
    { key: "op", name: "pipes, redirects", scopes: ["keyword.operator.pipe.shell", "keyword.operator.redirect.shell", "keyword.operator.logical.shell", "keyword.operator.assignment.shell", "keyword.operator.list.shell"] },
    { key: "mod", name: "export, local", scopes: ["storage.modifier.shell"] },
    { key: "str", name: "strings", scopes: ["string.quoted.double.shell", "string.quoted.single.shell", "string.unquoted.heredoc.shell"] },
    { key: "interp", name: "$variables", scopes: ["variable.parameter.positional.shell", "variable.language.special.shell", "punctuation.definition.variable.shell", "meta.parameter-expansion.shell"] },
  ] },
}
const HEX = /^#[0-9a-f]{6}$/i
// What is kept: `{dark: {elixir: {...}, json: {...}}, light: {...}}`. A
// ground holding the keys themselves is the shape of the first days,
// when there was one language for colour: it was Elixir's.
const clean = c => Object.fromEntries(KEYS.filter(k => HEX.test((c || {})[k] || "")).map(k => [k, c[k].toLowerCase()]))
const cleanGround = g => {
  if (!g) return {}
  if (KEYS.some(k => k in g)) return { elixir: clean(g) }
  return Object.fromEntries(Object.keys(LANGS).filter(l => g[l]).map(l => [l, clean(g[l])]))
}
const coloursOf = () => { try { const c = JSON.parse(store.get(COLOURS_KEY) || "{}"); return c.dark || c.light ? { dark: cleanGround(c.dark), light: cleanGround(c.light) } : { dark: cleanGround(c), light: {} } } catch (e) { return { dark: {}, light: {} } } }
function applyColours(all) {
  const root = document.documentElement.style, g = all[ground()] || {}
  for (const l of Object.keys(LANGS)) for (const k of KEYS) { const v = (g[l] || {})[k]; if (v) root.setProperty(`--t-${l}-${k}`, v); else root.removeProperty(`--t-${l}-${k}`) }
}
applyColours(coloursOf())
// The ground changes under the palette — the toggle, or the machine —
// and the other set goes on; whoever draws swatches listens too.
const onGround = f => { new MutationObserver(f).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] }); matchMedia("(prefers-color-scheme: dark)").addEventListener("change", f) }
onGround(() => applyColours(coloursOf()))
// The colour a language's role shows now: the reader's, or the stylesheet's.
const shownColour = (lang, key) => getComputedStyle(document.documentElement).getPropertyValue(`--t-${lang}-${key}`).trim().toLowerCase()
// A jsonc is JSON with comments and trailing commas. VS Code's settings
// carry the rules under editor.tokenColorCustomizations.textMateRules, a
// theme file under tokenColors, and a bare array is taken as the rules;
// the diff's four and the terminal's nine sit under
// workbench.colorCustomizations (a theme's `colors`) by VS Code's names,
// and the overlay under dew.interface, which a theme carries no more (the face is the reader's since 2026-09-30),
// which is this console's own.
function parseJsonc(text) {
  const bare = text.replace(/("(?:[^"\\]|\\.)*")|\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, (m, str) => str || "").replace(/,(\s*[}\]])/g, "$1")
  return JSON.parse(bare)
}
const rulesOf = doc => { const r = Array.isArray(doc) ? doc : doc.tokenColors || (doc["editor.tokenColorCustomizations"] || doc).textMateRules; return Array.isArray(r) ? r : [] }
// A VS Code colour may carry alpha, #rrggbbaa: the swatch takes six.
const hex6 = v => typeof v === "string" && /^#[0-9a-f]{6}([0-9a-f]{2})?$/i.test(v) ? v.slice(0, 7).toLowerCase() : null
const setOfDoc = (spec, doc) => { const c = (!Array.isArray(doc) && (doc["workbench.colorCustomizations"] || doc.colors)) || {}; return Object.fromEntries(spec.roles.flatMap(r => { const v = hex6(c[r.vs]); return v ? [[r.key, v]] : [] })) }
// A rule's scope covers a role's when it is the same, or a parent of it.
const covers = (rule, scope) => scope === rule || scope.startsWith(rule + ".")
// The rules, sorted into languages: `{elixir: {kw: "#..."}, json: {...}}`.
// A role takes the rule that covers the most of its scopes, and of two
// that cover as many, the later. Roles share scopes — a template's
// assigns are Elixir's module attributes, the shell's `$` is among its
// quotes and its variables — and until 2026-10-01 any rule that touched
// a role took it, so the later role's colour reached the earlier one:
// the shell's quotes were read in its variables' colour.
function coloursFromRules(rules) {
  const out = {}, most = {}
  for (const r of rules) {
    const fg = r.settings && r.settings.foreground
    if (!fg || !HEX.test(fg)) continue
    const scopes = (Array.isArray(r.scope) ? r.scope : String(r.scope || "").split(",")).map(x => x.trim()).filter(Boolean)
    for (const [l, lang] of Object.entries(LANGS)) for (const role of lang.roles) {
      const n = role.scopes.filter(ts => scopes.some(rs => covers(rs, ts))).length, id = `${l} ${role.key}`
      if (n && n >= (most[id] || 0)) { most[id] = n; (out[l] ||= {})[role.key] = fg.toLowerCase() }
    }
  }
  return out
}
// Read with the page on a ground it is not on: the attribute set for
// the reading and put back — the observers that follow it fire after,
// and find it as it was.
const onGroundRead = (g, f) => { const root = document.documentElement, had = root.getAttribute("data-theme"); root.setAttribute("data-theme", g); try { return f() } finally { if (had === null) root.removeAttribute("data-theme"); else root.setAttribute("data-theme", had) } }
// --- sets of colours on the root, a ground each, kept in this browser
// like the palettes. Each set is one shelf's: the terminal's — its
// ground, ink and dim, the sixteen ANSI colours a line wears, and the
// lines' grounds (tokens.css, on the root: a value set here on the
// root's own style wins over the sheet's), red an error's and yellow a
// warning's on the Logs screen and in a job's output, shown in the
// miniature's terminal — and the code's two: the sheet's — its ground,
// which was the terminal's until 2026-09-30 (`--sheet`, console.css,
// the terminal's still when nothing says otherwise), and the line
// numbers' own ground and ink — and the diff's four — the ground of an
// added line and of a removed one, and the colour of the number and the
// sign on each (`--diff-<key>`), shown in the tab's sample, which has
// one line of each. Each role names the property it writes and the VS
// Code colour it is, for the file; `rows` says how a box lays them out,
// a null being an empty record that ends a row early.
const SETS = {
  term: {
    key: "wb-console-term", root: "#term-swatches", data: "term", kind: "terminal",
    rows: {
      term: ["term", null, "term-ink", "term-dim"],
      ansi: ["black", "bright-black", "red", "bright-red", "green", "bright-green", "yellow", "bright-yellow", "blue", "bright-blue", "magenta", "bright-magenta", "cyan", "bright-cyan", "white", "bright-white"],
      lines: ["line-error", "line-warning", "line-highlight"],
    },
    roles: [
      { key: "term", name: "background", prop: "--term", vs: "terminal.background" },
      { key: "term-ink", name: "foreground", prop: "--term-ink", vs: "terminal.foreground" },
      // Dim is the terminal's own — timestamps, comments — and VS Code has no name for it.
      { key: "term-dim", name: "dim", prop: "--term-dim", vs: "dew.terminal.dim" },
      { key: "black", name: "black", prop: "--ansi-black", vs: "terminal.ansiBlack" },
      { key: "red", name: "red", title: "ANSI red: an error's line", prop: "--ansi-red", vs: "terminal.ansiRed" },
      { key: "green", name: "green", prop: "--ansi-green", vs: "terminal.ansiGreen" },
      { key: "yellow", name: "yellow", title: "ANSI yellow: a warning's line", prop: "--ansi-yellow", vs: "terminal.ansiYellow" },
      { key: "blue", name: "blue", prop: "--ansi-blue", vs: "terminal.ansiBlue" },
      { key: "magenta", name: "magenta", prop: "--ansi-magenta", vs: "terminal.ansiMagenta" },
      { key: "cyan", name: "cyan", prop: "--ansi-cyan", vs: "terminal.ansiCyan" },
      { key: "white", name: "white", prop: "--ansi-white", vs: "terminal.ansiWhite" },
      { key: "bright-black", name: "bright black", prop: "--ansi-bright-black", vs: "terminal.ansiBrightBlack" },
      { key: "bright-red", name: "bright red", prop: "--ansi-bright-red", vs: "terminal.ansiBrightRed" },
      { key: "bright-green", name: "bright green", prop: "--ansi-bright-green", vs: "terminal.ansiBrightGreen" },
      { key: "bright-yellow", name: "bright yellow", prop: "--ansi-bright-yellow", vs: "terminal.ansiBrightYellow" },
      { key: "bright-blue", name: "bright blue", prop: "--ansi-bright-blue", vs: "terminal.ansiBrightBlue" },
      { key: "bright-magenta", name: "bright magenta", prop: "--ansi-bright-magenta", vs: "terminal.ansiBrightMagenta" },
      { key: "bright-cyan", name: "bright cyan", prop: "--ansi-bright-cyan", vs: "terminal.ansiBrightCyan" },
      { key: "bright-white", name: "bright white", prop: "--ansi-bright-white", vs: "terminal.ansiBrightWhite" },
      // The highlights, the grounds a line wears: washes the sheet lays at
      // 8%, the hover's tint at 5% (console.css); VS Code has a name for the tint alone.
      { key: "line-error", name: "error", title: "an error's line", prop: "--line-error", vs: "dew.terminal.errorLine" },
      { key: "line-warning", name: "warning", title: "a warning's line", prop: "--line-warning", vs: "dew.terminal.warningLine" },
      { key: "line-highlight", name: "hover", title: "the line under the pointer", prop: "--line-highlight", vs: "editor.lineHighlightBackground" },
    ],
  },
  sheet: {
    key: "wb-console-sheet", root: "#sheet-swatches", data: "sheet", kind: "code",
    rows: { sheet: ["sheet", "sheet-ink", "sheet-num-bg", "sheet-num"] },
    roles: [
      { key: "sheet", name: "line background", prop: "--sheet", vs: "editor.background" },
      // The sheet's own ink: what a file with no language is read in — a language's code has its palette's.
      { key: "sheet-ink", name: "line foreground", title: "the ink of a file with no language", prop: "--sheet-ink", vs: "editor.foreground" },
      { key: "sheet-num-bg", name: "number background", title: "the line numbers' background", prop: "--sheet-num-bg", vs: "editorGutter.background" },
      { key: "sheet-num", name: "number foreground", title: "the line numbers' foreground", prop: "--sheet-num", vs: "editorLineNumber.foreground" },
    ],
  },
  diff: {
    key: "wb-console-diff", root: "#diff-swatches", data: "diff", kind: "code",
    rows: { diff: ["add-bg", "add-num", "del-bg", "del-num"] },
    roles: [
      { key: "add-bg", name: "+line background", title: "an added line's background", prop: "--diff-add-bg", vs: "diffEditor.insertedLineBackground" },
      { key: "add-num", name: "+line foreground", title: "an added line's number and sign", prop: "--diff-add-num", vs: "editorGutter.addedBackground" },
      { key: "del-bg", name: "-line background", title: "a removed line's background", prop: "--diff-del-bg", vs: "diffEditor.removedLineBackground" },
      { key: "del-num", name: "-line foreground", title: "a removed line's number and sign", prop: "--diff-del-num", vs: "editorGutter.deletedBackground" },
    ],
  },
}
// Which sets are a shelf's, and which palettes: the terminal's one set; the code's two and every language's palette.
const KIND_SETS = { terminal: ["term"], code: ["sheet", "diff"] }
// A ground's opacity is the reader's, like the face, over any theme — the terminal's (wb-console-term-alpha) and
// the sheet's (wb-console-sheet-alpha, 2026-10-01), each 0 to 100 and 40 until the reader says otherwise: composed
// onto the ground's colour as it goes on the root, #rrggbbaa under 100 %, and never written to a theme's file.
const ALPHA_KEYS = { term: "wb-console-term-alpha", sheet: "wb-console-sheet-alpha" }, ALPHA_DEFAULT = 40
const alphaOf = which => { const v = store.get(ALPHA_KEYS[which]); if (v === null || v === undefined || v === "") return ALPHA_DEFAULT; const n = Number(v); return Number.isFinite(n) && n >= 0 && n <= 100 ? n : ALPHA_DEFAULT }
const termAlpha = () => alphaOf("term")
const withAlpha = (v, pct) => v.slice(0, 7) + (pct >= 100 ? "" : Math.round(pct * 2.55).toString(16).padStart(2, "0"))
const cleanSet = (spec, d) => Object.fromEntries(spec.roles.filter(r => HEX.test((d || {})[r.key] || "")).map(r => [r.key, d[r.key].toLowerCase()]))
const setOf = spec => { try { const d = JSON.parse(store.get(spec.key) || "{}"); return { dark: cleanSet(spec, d.dark), light: cleanSet(spec, d.light) } } catch (e) { return { dark: {}, light: {} } } }
// The colour a property shows now: the reader's, or the stylesheet's.
const shownProp = prop => getComputedStyle(document.documentElement).getPropertyValue(prop).trim().toLowerCase()
function applySet(spec, all) {
  const root = document.documentElement.style, g = all[ground()] || {}
  for (const r of spec.roles) { const v = g[r.key]; if (v) root.setProperty(r.prop, v); else root.removeProperty(r.prop) }
  // The terminal's ground wears the reader's opacity, over the theme's colour or the house's; the sheet's is
  // composed again with it, its own or the house's, never the terminal's.
  if (spec.key === SETS.term.key) { const pct = termAlpha(); if (pct < 100) root.setProperty("--term", withAlpha(shownProp("--term"), pct)); sheetGround(setOf(SETS.sheet)) }
  if (spec.key === SETS.sheet.key) sheetGround(all)
}
// The sheet's ground with the reader's opacity: over its own colour, the theme's or the reader's, or over the
// house's when it has none — tokens.css's --sheet, read with the reader's value taken off the root first. It
// stood on the terminal's colour until 2026-10-02, and a reader who had kept no code theme saw House's sheet
// turn the terminal theme's colour (Selenized's teal) the moment the terminal wore one.
function sheetGround(all) {
  const own = (all[ground()] || {}).sheet, root = document.documentElement.style
  root.removeProperty("--sheet")
  root.setProperty("--sheet", withAlpha(own || shownProp("--sheet") || shownProp("--term"), alphaOf("sheet")))
}
for (const spec of Object.values(SETS)) { applySet(spec, setOf(spec)); onGround(() => applySet(spec, setOf(spec))) }
// --- the colour roles, one component (console.css .roles): a table of
// name | colour pairs. A box lays its rows out as its list says, an
// empty record where the list says null, and is fitted: its longest
// name is measured into --role-w so no name breaks and as many pairs
// as fit share a row, data-pairs capping them; on a row of two pairs or
// more the even pairs are mirrored, colour then name, the tracks with
// them, so two colours meet at the axis. A hidden box measures nothing
// and is fitted when it comes into view (the fold, the part, a resize).
const roleRow = (key, name, title, value, label, onInput, onChange) => {
  const row = document.createElement("label"), span = document.createElement("span"), input = document.createElement("input")
  row.dataset.role = key
  if (title) row.title = title
  span.textContent = name
  input.type = "color"; input.value = value; input.setAttribute("aria-label", label)
  input.addEventListener("input", () => onInput(input.value.toLowerCase()))
  input.addEventListener("change", onChange)
  row.append(span, input); return row
}
const emptyRecord = () => { const row = document.createElement("label"); row.className = "none"; row.setAttribute("aria-hidden", "true"); row.append(document.createElement("span"), document.createElement("span")); return row }
function fitRoles(box) {
  const names = [...box.querySelectorAll("label>span:first-child")]
  if (!names.length || !box.offsetParent) return
  // Measuring lays the box out with no minimum, many pairs a row and a
  // fraction of its height: the column's scroll is clamped to that
  // height and never put back, so it is kept here and put back below.
  const port = box.closest(".ctl"), scrolled = port ? port.scrollTop : 0
  const had = box.style.getPropertyValue("--role-w"); box.style.setProperty("--role-w", "0px"); box.style.gridTemplateColumns = ""
  let w = Math.max(...names.map(n => n.scrollWidth)); if (!w) { box.style.setProperty("--role-w", had); if (port) port.scrollTop = scrolled; return }
  const cap = Number(box.dataset.pairs)
  if (cap) w = Math.max(w, Math.floor((box.clientWidth - cap * 20 - (2 * cap - 1) * 5) / cap))
  w = Math.ceil(w); box.style.setProperty("--role-w", `${w}px`)
  const cols = Math.max(1, Math.floor((box.clientWidth + 5) / (w + 25)))
  box.classList.toggle("paired", cols >= 2)
  box.style.gridTemplateColumns = cols >= 2 ? Array.from({ length: cols }, (_, i) => i % 2 ? `20px minmax(${w}px,1fr)` : `minmax(${w}px,1fr) 20px`).join(" ") : ""
  for (const none of box.querySelectorAll("label.none")) none.classList.toggle("alone", cols < 2)
  box.querySelectorAll("label").forEach((row, i) => {
    const mirror = cols >= 2 && (i % cols) % 2 === 1, first = mirror ? row.querySelector("input") : row.querySelector("span")
    row.classList.toggle("mirror", mirror); if (first && row.firstElementChild !== first) row.prepend(first)
  })
  if (port) port.scrollTop = scrolled
}
const fitAll = el => { for (const box of el.querySelectorAll(".roles")) fitRoles(box) }
function bindSet(el, spec) {
  const boxes = [...el.querySelectorAll(`${spec.root} [data-${spec.data}]`)]
  if (!boxes.length) return {}
  let all = setOf(spec)
  const mine = () => all[ground()] || {}
  const set = d => { all = { ...all, [ground()]: d }; applySet(spec, all) }
  const keep = () => { store.set(spec.key, JSON.stringify(all)); touched(el, spec.kind) }
  // Drawn from the root as it stands: the ground may have changed before
  // this box was bound (the ground hook mounts first), and an observer
  // registered after a change never hears it — so the set goes on first.
  const draw = () => {
    applySet(spec, all)
    for (const box of boxes) {
      box.replaceChildren(...(spec.rows[box.dataset[spec.data]] || []).map(key => {
        if (!key) return emptyRecord()
        const role = spec.roles.find(r => r.key === key)
        return roleRow(role.key, role.name, role.title, shownProp(role.prop).slice(0, 7), `${role.title || role.name}, the colour`, v => set({ ...mine(), [role.key]: v }), keep)
      }))
      fitRoles(box)
    }
  }
  onGround(() => { all = setOf(spec); draw() })
  draw()
  return { take: d => { set({ ...mine(), ...d }); store.set(spec.key, JSON.stringify(all)); draw() }, replace: both => { all = { dark: cleanSet(spec, both.dark), light: cleanSet(spec, both.light) }; applySet(spec, all); store.set(spec.key, JSON.stringify(all)); draw() }, redraw: draw }
}
function bindColours(el) {
  const swatches = el.querySelector("#swatches"), select = el.querySelector("#colours-lang")
  if (!swatches || !select) return {}
  let all = coloursOf(), lang = "elixir"
  const mine = () => (all[ground()] || {})[lang] || {}
  const set = c => { const g = ground(); all = { ...all, [g]: { ...(all[g] || {}), [lang]: c } }; applyColours(all) }
  const merge = found => { const g = ground(), was = all[g] || {}; all = { ...all, [g]: Object.fromEntries(Object.keys(LANGS).map(l => [l, { ...(was[l] || {}), ...(found[l] || {}) }])) }; applyColours(all) }
  const keep = () => { store.set(COLOURS_KEY, JSON.stringify(all)); touched(el, "code") }
  const draw = () => {
    applyColours(all)
    select.value = lang
    for (const s of el.querySelectorAll(".sample[data-lang]")) s.hidden = s.dataset.lang !== lang
    // Other, a file with no language, has no palette: the sheet's foreground, above, is its ink.
    const roles = LANGS[lang]?.roles || [], none = el.querySelector("#swatches-none")
    swatches.replaceChildren(...roles.map(role => roleRow(role.key, role.name, role.title, shownColour(lang, role.key), `${role.title || role.name}, the colour`, v => set({ ...mine(), [role.key]: v }), keep)))
    if (none) none.hidden = roles.length > 0
    fitRoles(swatches)
  }
  select.addEventListener("change", () => { lang = select.value in LANGS || select.value === "other" ? select.value : "elixir"; draw() })
  onGround(() => { all = coloursOf(); draw() })
  draw()
  // What a file brings: the rules found, merged into this ground's palettes; a theme, both grounds whole.
  return { take: found => { merge(found); store.set(COLOURS_KEY, JSON.stringify(all)); draw() }, replace: both => { all = { dark: cleanGround(both.dark), light: cleanGround(both.light) }; applyColours(all); store.set(COLOURS_KEY, JSON.stringify(all)); draw() }, redraw: draw }
}
// --- the themes: two, one a surface, each a file on its shelf —
// `<key>.terminal.json` the terminal's colours, `<key>.code.json` the
// sheet, every language's palette and the diff's — read by
// Console.Themes and handed to the pane as JSON. Each carries dew.theme
// (its name, its author, where it lives, its licence) and a block a
// ground, `dark` and `light`, in the keys VS Code uses. A theme is
// colours: the face is the reader's own, chosen above the shelf. Picking one
// replaces its surface whole, what it does not say being the house's.
// Custom is what the reader set on top of a theme — a card that appears
// at the first touch, never a file on the shelf. Picking a theme, the
// one Custom stands on (its card dashed) or any other, puts that theme
// on whole and puts Custom away, kept: its card stays, and pressing it
// wears it again. There is one Custom a shelf: touching a colour while
// another theme is worn makes that theme and the touch the new Custom,
// and the one kept is gone (2026-10-01; until then picking a theme lost
// it at once). What is yours is counted on the fold's head, this
// ground's, and nowhere else. Settled on 2026-09-30
// (console/la-estanteria-a-la-vista.html), after the one theme for the
// interface whole of the day before.
const SHELF_KEYS = { terminal: "wb-console-theme-terminal", code: "wb-console-theme-code" }
const isTheme = doc => !Array.isArray(doc) && !!(doc["dew.theme"] || doc.dark || doc.light)
// What a theme carries was touched — a face, a colour, a palette. The
// shelf of that surface hears it and says Custom; the band, the rail
// and the ground are not a theme's, and say nothing.
const touched = (el, kind) => { if (kind) el.dispatchEvent(new CustomEvent("wb:touched", { detail: { kind } })) }
const blockIn = (doc, g) => (doc && doc[g] && typeof doc[g] === "object") ? doc[g] : {}
// What a doc carries of a shelf: the sets, and for the code the palettes and the sheet.
const carries = (doc, kind) => KIND_SETS[kind].some(k => Object.keys(setOfDoc(SETS[k], blockIn(doc, "dark"))).length || Object.keys(setOfDoc(SETS[k], blockIn(doc, "light"))).length) || (kind === "code" && (rulesOf(blockIn(doc, "dark")).length > 0 || rulesOf(blockIn(doc, "light")).length > 0))
// One ground's colours of a shelf as VS Code keys them: the sets under
// workbench.colorCustomizations, the palettes as textMateRules.
// A role as a theme's rules: its scopes with its colour — and, where some of them are set in italic and the rest
// are not (a parameter among the operators: `italic` on the role), those apart in a rule of their own, so a file
// carried to VS Code slants what the sheet slants.
const rulesOfRole = (role, foreground) => {
  const rule = (scopes, style) => ({ scope: scopes.length === 1 ? scopes[0] : scopes, settings: { ...(style ? { fontStyle: style } : {}), foreground } })
  const slanted = role.italic || [], upright = role.scopes.filter(sc => !slanted.includes(sc))
  return [rule(upright, role.style), ...(slanted.length ? [rule(slanted, "italic")] : [])]
}
const blockOf = kind => ({
  "workbench.colorCustomizations": Object.fromEntries(KIND_SETS[kind].flatMap(k => SETS[k].roles.map(r => [r.vs, shownProp(r.prop).slice(0, 7)]))),
  ...(kind === "code" ? { "editor.tokenColorCustomizations": { textMateRules: Object.entries(LANGS).flatMap(([l, lang]) => lang.roles.flatMap(role => rulesOfRole(role, shownColour(l, role.key)))) } } : {}),
})
function bindShelves(el, deps) {
  let shelf = []
  try { shelf = JSON.parse(el.querySelector("#themes")?.textContent || "[]") } catch (e) {}
  const shelves = {}
  for (const kind of Object.keys(SHELF_KEYS)) shelves[kind] = bindShelf(el, kind, shelf.filter(t => t.kind === kind), deps, shelves)
  // The folds: every head of the tab has one (2026-10-01) — Overlay's two, a theme's Style and its adjustments,
  // Credits' groups. Unfolded, the pairs are fitted.
  for (const b of el.querySelectorAll(".group>h5>.foldsq")) b.addEventListener("click", () => {
    const g = b.closest(".group"), folded = g.toggleAttribute("data-folded")
    b.setAttribute("aria-expanded", String(!folded)); b.title = folded ? "Unfold" : "Fold"
    if (!folded) fitAll(el)
  })
  return shelves
}
function bindShelf(el, kind, themes, { colours, sets }, shelves) {
  const part = el.querySelector(`.part[data-part="${kind}"]`); if (!part) return {}
  const cards = [...part.querySelectorAll(".grounds.themes .ttile")], custom = cards.find(c => c.dataset.themeKey === "custom"), touch = part.querySelector(".tsec .touch")
  const word = part.querySelector("[data-theme-word]"), down = part.querySelector("[data-theme-download]"), file = part.querySelector("[data-theme-file]"), clear = part.querySelector("[data-theme-clear]")
  const say = (text, bad) => { if (word) { word.textContent = text; word.classList.toggle("bad", !!bad) } }
  const house = themes.find(t => t.key === "default")?.json || {}
  const mySets = KIND_SETS[kind].map(k => [k, SETS[k]])
  // What is kept: the theme in force, whether something is set on top of it — Custom, worn — and, when a theme is
  // worn bare, the Custom put away: the theme it stood on and the stores as they were, both grounds.
  const known = key => themes.some(t => t.key === key) ? key : "default"
  const keptOf = k => (k && typeof k === "object" && k.sets && typeof k.sets === "object") ? { key: known(k.key), sets: k.sets, colours: (k.colours && typeof k.colours === "object") ? k.colours : {} } : null
  const stateOf = () => { try { const s = JSON.parse(store.get(SHELF_KEYS[kind]) || "null"); if (s && typeof s === "object") return { key: known(s.key), custom: !!s.custom, kept: s.custom ? null : keptOf(s.kept) } } catch (e) {} return { key: "default", custom: false, kept: null } }
  let state = stateOf(), applying = false
  const keepState = () => store.set(SHELF_KEYS[kind], JSON.stringify(state))
  const docOf = key => themes.find(t => t.key === key)?.json
  const setsFrom = doc => Object.fromEntries(mySets.map(([k, spec]) => [k, { dark: setOfDoc(spec, blockIn(doc, "dark")), light: setOfDoc(spec, blockIn(doc, "light")) }]))
  const rulesFrom = doc => ({ dark: coloursFromRules(rulesOf(blockIn(doc, "dark"))), light: coloursFromRules(rulesOf(blockIn(doc, "light"))) })
  // The theme, whole: every control of its surface takes what it says; what it does not say goes back to the house's.
  const apply = doc => {
    applying = true
    try {
      const both = setsFrom(doc); for (const [k] of mySets) sets[k].replace?.(both[k])
      if (kind === "code") colours.replace?.(rulesFrom(doc))
    } finally { applying = false }
  }
  // Custom as the stores hold it now, to put away; and one put away, worn again.
  const snapshot = () => ({ key: state.key, sets: Object.fromEntries(mySets.map(([k, spec]) => [k, setOf(spec)])), ...(kind === "code" ? { colours: coloursOf() } : {}) })
  const wear = kept => {
    applying = true
    try {
      for (const [k] of mySets) sets[k].replace?.(kept.sets[k] || {})
      if (kind === "code") colours.replace?.(kept.colours || {})
    } finally { applying = false }
  }
  // What is set on this ground that the theme in force does not say: the keys, a set and a language each.
  const yours = () => {
    const g = ground(), doc = docOf(state.key), both = doc ? setsFrom(doc) : {}, want = doc ? rulesFrom(doc)[g] : {}
    const differ = (have, w) => Object.keys(have).filter(key => have[key] !== w[key])
    return {
      sets: Object.fromEntries(mySets.map(([k, spec]) => [k, differ(setOf(spec)[g] || {}, (both[k] || {})[g] || {})])),
      langs: kind === "code" ? Object.fromEntries(Object.entries(coloursOf()[g] || {}).map(([l, have]) => [l, differ(have || {}, want[l] || {})])) : {},
    }
  }
  const count = ({ sets, langs }) => [...Object.values(sets), ...Object.values(langs)].reduce((n, keys) => n + keys.length, 0)
  // And each wears the accent on its name, in the rows of its part: the count on the fold's head says how many,
  // the names say which (2026-10-01). Of the languages, the one the select shows.
  const mark = ({ sets, langs }) => {
    for (const [k, spec] of mySets) for (const row of el.querySelectorAll(`${spec.root} [data-${spec.data}] label[data-role]`)) row.classList.toggle("yours", sets[k].includes(row.dataset.role))
    if (kind === "code") { const shown = langs[el.querySelector("#colours-lang")?.value] || []; for (const row of el.querySelectorAll("#swatches label[data-role]")) row.classList.toggle("yours", shown.includes(row.dataset.role)) }
  }
  // A thumbnail: both grounds, the ground's colour and five lines of the theme's; what a theme does not say, the house's says.
  const W = [55, 38, 66, 30, 48]
  const six = (doc, g) => {
    const c = { ...(blockIn(house, g)["workbench.colorCustomizations"] || {}), ...(blockIn(doc, g)["workbench.colorCustomizations"] || {}) }
    if (kind === "terminal") return ["terminal.background", "terminal.ansiRed", "terminal.ansiGreen", "terminal.ansiBlue", "terminal.ansiMagenta", "dew.terminal.dim"].map(k => hex6(c[k]) || "#808080")
    const p = { ...(rulesFrom(house)[g].elixir || {}), ...(rulesFrom(doc)[g].elixir || {}) }
    return [hex6(c["editor.background"]) || "#808080", ...["kw", "str", "func", "mod", "comment"].map(k => p[k] || "#808080")]
  }
  const half = v => `<span class="half" style="background:${v[0]}">${v.slice(1).map((c, i) => `<i style="background:${c};width:${W[i]}%"></i>`).join("")}</span>`
  const thumb = doc => half(six(doc, "dark")) + half(six(doc, "light"))
  // A snapshot as a doc: the theme it stands on under what it sets on top, both grounds.
  const docFrom = mine => {
    const doc = { "dew.theme": { name: "My theme", author: "", url: "", licence: "" } }
    for (const g of ["dark", "light"]) {
      const base = docOf(mine.key) || {}, c = { ...(blockIn(base, g)["workbench.colorCustomizations"] || {}) }
      for (const [k, spec] of mySets) for (const r of spec.roles) { const v = cleanSet(spec, (mine.sets[k] || {})[g])[r.key]; if (v) c[r.vs] = v }
      doc[g] = { "workbench.colorCustomizations": c }
      if (kind === "code") {
        const have = cleanGround((mine.colours || {})[g]), base = rulesFrom(docOf(mine.key) || {})[g]
        const all = Object.fromEntries(Object.keys(LANGS).map(l => [l, { ...(base[l] || {}), ...(have[l] || {}) }]))
        doc[g]["editor.tokenColorCustomizations"] = { textMateRules: Object.entries(LANGS).flatMap(([l, lang]) => lang.roles.filter(role => all[l][role.key]).flatMap(role => rulesOfRole(role, all[l][role.key]))) }
      }
    }
    return doc
  }
  // Mine, for Custom's card: as the stores hold it while it is worn, as it was put away while a theme is worn bare.
  const mineDoc = () => docFrom(!state.custom && state.kept ? state.kept : snapshot())
  // And what is worn now, whichever it is — a theme bare, or Custom on one: what Download Current gives.
  const currentDoc = () => docFrom(snapshot())
  const draw = () => {
    const on = state.custom ? "custom" : state.key, name = docOf(state.key)?.["dew.theme"]?.name || state.key
    // Custom's card: there while it is worn or put away, and it says the theme it stands on.
    const mine = state.custom || !!state.kept, under = state.custom ? name : docOf(state.kept?.key)?.["dew.theme"]?.name || state.kept?.key
    for (const c of cards) {
      const k = c.dataset.themeKey
      c.setAttribute("aria-pressed", String(k === on))
      if (k === "custom") { c.hidden = !mine; c.querySelector("small").textContent = mine ? `on ${under}` : ""; c.title = state.custom ? "" : "Back to what you set, as you left it"; if (mine) c.querySelector(".tthumb").innerHTML = thumb(mineDoc()) }
      else {
        const t = themes.find(x => x.key === k); c.querySelector(".tthumb").innerHTML = thumb(t.json)
        if (state.custom && k === state.key) { c.dataset.base = ""; c.title = `Back to ${name}, as it is on the shelf` } else { delete c.dataset.base; c.title = `${t.json["dew.theme"]?.author || ""} · ${t.json["dew.theme"]?.licence || t.json["dew.theme"]?.license || ""}` }
      }
    }
    // Clear Custom is there while there is one, as its card is, and says what a press leaves.
    if (clear) { clear.hidden = !mine; clear.title = state.custom ? `Forget what you set: ${name}, as it is on the shelf` : "Forget the Custom you put away" }
    const set = yours(), n = count(set)
    if (touch) touch.textContent = n ? `${n} set by you` : ""
    mark(set)
    // Credits: the theme in force wears it, unless Custom is on — then nothing on the shelf is.
    for (const c of el.querySelectorAll(`.credit[data-kind="${kind}"]`)) { const isOn = c.dataset.theme === state.key && !state.custom; c.toggleAttribute("data-on", isOn); const p = c.querySelector(".on"); if (p) { p.hidden = !isOn; p.textContent = isOn ? "In use" : "" } }
  }
  for (const c of cards) {
    const k = c.dataset.themeKey
    // Custom's card wears what was put away; while it is worn there is nothing to go back to.
    if (k === "custom") { c.addEventListener("click", () => { if (state.custom || !state.kept) return; const kept = state.kept; wear(kept); state = { key: kept.key, custom: true, kept: null }; keepState(); say(""); draw() }); continue }
    // A theme's card puts the theme on whole, and Custom away if it was worn; one already put away stays.
    c.addEventListener("click", () => { const kept = state.custom ? snapshot() : state.kept; apply(docOf(k)); state = { key: k, custom: false, kept }; keepState(); say(""); draw() })
  }
  // Custom, forgotten: worn, the theme it stands on goes on whole, as it is on the shelf; put away, it is dropped
  // and what is worn stays. Either way no Custom is left, and its card and this button go with it.
  clear?.addEventListener("click", () => { if (state.custom) apply(docOf(state.key)); state = { key: state.key, custom: false, kept: null }; keepState(); say(""); draw() })
  // The first touch on a theme worn bare: it and the touch are Custom now, in place of any put away. Any touch
  // after it changes what is yours, so the count and the names are drawn again.
  el.addEventListener("wb:touched", e => { if (e.detail?.kind !== kind || applying) return; if (!state.custom) { state = { ...state, custom: true, kept: null }; keepState() } draw() })
  // The palette's rows are drawn again for the language chosen: its names are marked again.
  if (kind === "code") el.querySelector("#colours-lang")?.addEventListener("change", () => mark(yours()))
  onGround(draw)
  // What is worn, as a file for the shelf: this surface's, both grounds, and a dew.theme to fill in. It gave Custom
  // even put away until 2026-10-01, when it was named for it; a Custom put away is worn first, a press on its card.
  down?.addEventListener("click", () => {
    const a = document.createElement("a"), blob = new Blob([JSON.stringify(currentDoc(), null, 2)], { type: "application/json" })
    a.href = URL.createObjectURL(blob); a.download = `my-theme.${kind}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 1000)
    say(`downloaded: give it its name, your name and a link in dew.theme, and drop it in console/themes/ as <key>.${kind}.json`)
  })
  // A file loads onto the shelf it belongs to, by what it carries — a
  // theme of the other surface goes to that shelf; a VS Code theme (no
  // ground blocks: tokenColors, colors) is taken onto this ground, by
  // both shelves, what each finds of its own.
  const load = doc => {
    if (isTheme(doc)) {
      const kinds = Object.keys(SHELF_KEYS).filter(k => carries(doc, k))
      if (!kinds.length) return say("nothing of it is a theme's: no colour of the terminal's, the sheet's or the diff's, no rule", true)
      for (const k of kinds) shelves[k].takeWhole(doc)
      say(`${doc["dew.theme"]?.name || "the file"}, both grounds, on ${kinds.join(" and ")} — Custom now, yours to download`)
    } else {
      const found = coloursFromRules(rulesOf(doc)), said = []
      for (const k of Object.keys(SHELF_KEYS)) {
        const taken = KIND_SETS[k].map(s => [s, setOfDoc(SETS[s], doc)]).filter(([, d]) => Object.keys(d).length)
        const n = k === "code" ? Object.values(found).reduce((a, c) => a + Object.keys(c).length, 0) : 0
        if (!taken.length && !n) continue
        shelves[k].takePart({ taken, found: k === "code" ? found : null })
        said.push(`${k}: ${[n && `${n} rule${n === 1 ? "" : "s"}`, ...taken.map(([s, d]) => `${Object.keys(d).length} of the ${s === "term" ? "terminal" : s}'s`)].filter(Boolean).join(", ")}`)
      }
      if (!said.length) return say("nothing of it is this interface's: no rule, no colour of the terminal's, the sheet's or the diff's", true)
      say(`onto this ground — ${said.join("; ")}`)
    }
  }
  file?.addEventListener("change", () => {
    const f = file.files?.[0]; if (!f) return
    f.text().then(t => { try { load(parseJsonc(t)) } catch (e) { say(`not read: ${e.message}`, true) } file.value = "" })
  })
  draw()
  return {
    // A whole theme of this surface, from a file: worn, and Custom, since it is not on the shelf.
    takeWhole: doc => { apply(doc); state = { ...state, custom: true, kept: null }; keepState(); draw() },
    // Part of one, onto this ground.
    takePart: ({ taken, found }) => { applying = true; try { for (const [k, d] of taken) sets[k].take?.(d); if (found) colours.take?.(found) } finally { applying = false } state = { ...state, custom: true, kept: null }; keepState(); draw() },
    redraw: draw,
    mine: mineDoc,
  }
}

export const Frame = {
  mounted() {
    const el = this.el, body = document.body, mini = el.querySelector("#mini")
    const state = () => ({ bottom: body.classList.contains("band-bottom"), right: body.classList.contains("rail-right"), off: body.classList.contains("rail-off") })
    const paint = () => {
      const s = state()
      // A card of the frame shows the frame it would set — the other axis as it stands — so every position is in
      // view, and the one in force is the pressed one.
      for (const b of el.querySelectorAll("[data-axis] button[data-pick]")) {
        const want = PICKS[b.dataset.pick], on = Object.entries(want).every(([k, v]) => s[k] === v) && (b.dataset.pick !== "left" && b.dataset.pick !== "right" || !s.off)
        b.setAttribute("aria-pressed", String(on))
        const thumb = b.querySelector(".thumb"), would = { ...s, ...want }
        if (thumb) for (const k of ["bottom", "right", "off"]) thumb.classList.toggle(k, !!would[k])
      }
      // The ground's cards are the page too: their thumbnails wear the frame in force (System's is two, one a ground)
      // and, as the frame's own do through --term, the terminal's ground as the reader has it — the theme's colour
      // for that card's ground when it says one, and the opacity. A card is a ground the page may not be on, so the
      // colour is read from what is kept and handed to the thumbnail (--tm, --tm-a), the stylesheet's being the house's.
      const kept = setOf(SETS.term), pct = termAlpha()
      for (const thumb of el.querySelectorAll(".swatch[data-ground] .thumb:not(.system)")) {
        for (const k of ["bottom", "right", "off"]) thumb.classList.toggle(k, !!s[k])
        const own = (kept[thumb.classList.contains("dark") ? "dark" : "light"] || {}).term
        if (own) thumb.style.setProperty("--tm", own); else thumb.style.removeProperty("--tm")
        thumb.style.setProperty("--tm-a", `${pct}%`)
      }
      if (mini) { mini.classList.toggle("bottom", s.bottom); mini.classList.toggle("right", s.right); mini.classList.toggle("off", s.off) }
      const chosen = store.get(THEME_KEY) || "system"
      for (const c of el.querySelectorAll(".swatch[data-ground]")) c.setAttribute("aria-pressed", String(c.dataset.ground === chosen))
    }
    const setFrame = want => {
      const s = { ...state(), ...want }
      body.classList.toggle("band-bottom", s.bottom); body.classList.toggle("rail-right", s.right); body.classList.toggle("rail-off", s.off)
      store.set("wb-console-frame", JSON.stringify(FRAME_CLASSES.filter(c => body.classList.contains(c))))
      paint(); dispatchEvent(new Event("resize"))
    }
    for (const b of el.querySelectorAll("[data-axis] button[data-pick]")) b.addEventListener("click", () => setFrame(PICKS[b.dataset.pick]))
    // The miniature is a control too: the band moves, the rail changes side.
    mini?.querySelector(".mband")?.addEventListener("click", () => setFrame({ bottom: !state().bottom }))
    mini?.querySelector(".mrail")?.addEventListener("click", () => setFrame({ right: !state().right }))
    // And its ground cell switches the ground, as the band's does; the click stays off the band, which would move it.
    mini?.querySelector(".mground")?.addEventListener("click", ev => { ev.stopPropagation(); setGround(ground() === "dark" ? "light" : "dark") })
    // The ground: light, dark, or the machine's — which is no choice kept, the way the page boots.
    const setGround = g => {
      if (g === "system") { try { localStorage.removeItem(THEME_KEY) } catch (e) {} document.documentElement.removeAttribute("data-theme") }
      else { document.documentElement.setAttribute("data-theme", g); store.set(THEME_KEY, g) }
      paint(); document.getElementById("ground-toggle")?.dispatchEvent(new Event("repaint"))
    }
    for (const c of el.querySelectorAll(".swatch[data-ground]")) c.addEventListener("click", () => setGround(c.dataset.ground))
    // A theme's part switches it too, beside its shelf's name: the square says the ground it is on, whoever set it.
    const flips = [...el.querySelectorAll("[data-ground-flip]")]
    const paintFlips = () => { const dark = ground() === "dark"; for (const b of flips) { b.setAttribute("aria-pressed", String(dark)); b.title = dark ? "Dark ground — click for light" : "Light ground — click for dark" } }
    for (const b of flips) b.addEventListener("click", () => setGround(ground() === "dark" ? "light" : "dark"))
    onGround(paintFlips); paintFlips()
    // The code's and the files' face, size and leading, the reader's.
    const picks = Object.fromEntries(Object.keys(GROUPS).map(g => [g, bindPicks(el, g) || {}]))
    // And a ground's opacity, the reader's too, the terminal's and the sheet's: the slider and the number beside it
    // say one thing, whichever moves; kept, and the ground put on again with it.
    for (const which of Object.keys(ALPHA_KEYS)) {
      const alpha = el.querySelector(`#${which}-alpha`), alphaN = el.querySelector(`#${which}-alpha-n`)
      if (!alpha || !alphaN) continue
      const show = pct => { alpha.value = String(pct); alphaN.value = String(pct) }
      const take = v => { const pct = Math.max(0, Math.min(100, Math.round(Number(v)))); if (!Number.isFinite(pct)) return; show(pct); store.set(ALPHA_KEYS[which], String(pct)); applySet(SETS[which], setOf(SETS[which])) }
      show(alphaOf(which))
      alpha.addEventListener("input", () => take(alpha.value))
      alphaN.addEventListener("input", () => { if (alphaN.value !== "") take(alphaN.value) })
      alphaN.addEventListener("change", () => take(alphaN.value === "" ? alphaOf(which) : alphaN.value))
    }
    onGround(paint)
    this.repaint = paint; addEventListener("resize", paint)
    this.shelves = bindShelves(el, { colours: bindColours(el), sets: Object.fromEntries(Object.entries(SETS).map(([k, spec]) => [k, bindSet(el, spec)])) })
    this.refit = () => fitAll(el); addEventListener("resize", this.refit)
    // The controls folded in three until 2026-09-29 (wb-console-ui-folds); they are parts now, one in view.
    try { localStorage.removeItem("wb-console-ui-folds") } catch (e) {}
    this.part = el.dataset.part
    paint()
    // The miniature's service chips do what the Logs screen's do: pressed, the service's lines show.
    // (Logs hides the service column when one service alone shows: the name says nothing then.)
    for (const chip of el.querySelectorAll(".mini .toolbar .svc[data-svc]")) chip.addEventListener("click", () => {
      const on = chip.getAttribute("aria-pressed") !== "true"; chip.setAttribute("aria-pressed", String(on))
      for (const ln of el.querySelectorAll(`.mini .ln[data-svc="${chip.dataset.svc}"]`)) ln.hidden = !on
      const showing = [...el.querySelectorAll(".mini .toolbar .svc[data-svc]")].filter(c => c.getAttribute("aria-pressed") === "true").length
      el.querySelector(".mini .lines")?.classList.toggle("no-svc", showing === 1)
    })
    // And its Timestamps button: the Logs screen's, folding the time column away.
    el.querySelector(".mini .toolbar [data-ts]")?.addEventListener("click", ev => {
      const on = ev.currentTarget.getAttribute("aria-pressed") !== "true"; ev.currentTarget.setAttribute("aria-pressed", String(on))
      el.querySelector(".mini .lines")?.classList.toggle("no-ts", !on)
    })
    // The grip between the terminal and the sheet: the Jobs screen's, in
    // the miniature. The terminal's height is the choice, kept in this
    // browser; the sheet takes what is left. Halves until anyone drags.
    const grip = el.querySelector(".mini .ograb"), mmain = el.querySelector(".mini .mmain"), term = el.querySelector(".mini .lines"), sheet = el.querySelector(".mini .impl")
    if (grip && mmain && term && sheet) {
      const MIN = 72, KEY = "wb-console-mini-term"
      const cap = () => term.getBoundingClientRect().height + sheet.getBoundingClientRect().height - MIN
      const label = h => { grip.setAttribute("aria-valuenow", String(Math.round(h))); grip.setAttribute("aria-valuemin", String(MIN)); grip.setAttribute("aria-valuemax", String(Math.round(cap()))) }
      const set = px => { const h = Math.round(Math.min(cap(), Math.max(MIN, px))); mmain.style.setProperty("--term-h", h + "px"); label(h); return h }
      const forget = () => { mmain.style.removeProperty("--term-h"); label(term.getBoundingClientRect().height) }
      const keep = () => { const v = mmain.style.getPropertyValue("--term-h"); v ? store.set(KEY, v) : (() => { try { localStorage.removeItem(KEY) } catch (e) {} })() }
      const saved = parseInt(store.get(KEY) || "", 10); if (saved) set(saved); else label(term.getBoundingClientRect().height)
      grip.addEventListener("pointerdown", ev => {
        ev.preventDefault(); grip.setPointerCapture(ev.pointerId); grip.classList.add("dragging")
        const from = term.getBoundingClientRect().height - ev.clientY
        const move = e => set(e.clientY + from)
        const up = () => { grip.classList.remove("dragging"); grip.removeEventListener("pointermove", move); grip.removeEventListener("pointerup", up); grip.removeEventListener("pointercancel", up); keep() }
        grip.addEventListener("pointermove", move); grip.addEventListener("pointerup", up); grip.addEventListener("pointercancel", up)
      })
      grip.addEventListener("dblclick", () => { forget(); keep() })
      grip.addEventListener("keydown", ev => {
        const step = ev.shiftKey ? 48 : 16, h = term.getBoundingClientRect().height
        if (ev.key === "ArrowUp") set(h - step); else if (ev.key === "ArrowDown") set(h + step); else if (ev.key === "Home") forget(); else return
        ev.preventDefault(); keep()
      })
    }
    // The miniature's terminal follows its end, as the Logs screen does.
    const lines = mini?.querySelector(".lines"); if (lines) lines.scrollTop = lines.scrollHeight
  },
  // The part changed under the ribbon's patch: the column starts at its top.
  updated() {
    if (this.el.dataset.part === this.part) return
    this.part = this.el.dataset.part
    const ctl = this.el.querySelector(".ctl"); if (ctl) ctl.scrollTop = 0
    fitAll(this.el)
    // A part left may have changed what another draws: a terminal theme or its opacity, the cards of Overlay.
    this.repaint && this.repaint()
  },
  destroyed() { removeEventListener("resize", this.repaint); removeEventListener("resize", this.refit) },
}

// --- the terminal: the server pushes the session's lines, the input keeps its history.
export const Term = {
  mounted() {
    // One screen, many sessions: each session is its own process on the
    // server and keeps its trail; the hook shows the one the screen's key
    // names, and keeps a history per key so ↑ in psql never brings bash.
    const screen = this.el.querySelector("#term-screen"), histories = {}
    const history = () => { const k = this.el.dataset.key || ""; return histories[k] ||= new History() }
    const line = (html, cls) => { const d = document.createElement("div"); if (cls) d.className = cls; d.innerHTML = html; screen.append(d); while (screen.children.length > 2000) screen.firstChild.remove() }
    const bottom = () => { screen.scrollTop = screen.scrollHeight }
    this.handleEvent("term_out", ({ line: html, cls }) => { line(html, cls); bottom() })
    this.handleEvent("term_screen", ({ lines }) => { screen.replaceChildren(); for (const l of lines) line(l.line, l.cls); bottom() })
    const bind = () => {
      // The mark is a property, not a data- attribute: every patch drops
      // attributes the server did not render, and a dropped mark bound one
      // more listener per line sent — ↑ then stepped two, three lines at once.
      const input = this.el.querySelector("#term-input"); if (!input || input.termBound) return
      input.termBound = true
      input.addEventListener("keydown", ev => {
        if (ev.key === "Enter") { history().push(input.value); setTimeout(() => { input.value = "" }, 0) }
        else if (ev.key === "ArrowUp") { ev.preventDefault(); input.value = history().up(input.value) }
        else if (ev.key === "ArrowDown") { ev.preventDefault(); input.value = history().down(input.value) }
        // Ctrl+C is the browser's Copy while there is something to copy — a
        // selection in the input or on the screen — and the session's
        // interrupt when there is not, as the terminals in editors do.
        // Ctrl+Shift+C, and ⌘C on a Mac, stay Copy always.
        else if ((ev.key === "c" || ev.key === "C") && ev.ctrlKey && !ev.shiftKey && !ev.altKey && !ev.metaKey) {
          const picked = input.selectionStart !== input.selectionEnd || String(document.getSelection() || "") !== ""
          if (!picked) { ev.preventDefault(); this.pushEvent("term_interrupt", {}) }
        }
        else if (ev.key === "l" && ev.ctrlKey) { ev.preventDefault(); screen.replaceChildren(); this.pushEvent("term_clear", {}) }
        else if (ev.key === "PageUp") { ev.preventDefault(); screen.scrollTop -= screen.clientHeight * 0.8 }
        else if (ev.key === "PageDown") { ev.preventDefault(); screen.scrollTop += screen.clientHeight * 0.8 }
      })
      input.focus()
    }
    bind(); this.bind = bind
    // The screen asks for its session's trail once here, and again
    // whenever the key changes: a pick, or a status that moved it.
    this.key = this.el.dataset.key; this.pushEvent("term_look", {})
  },
  updated() {
    this.bind()
    if (this.el.dataset.key !== this.key) { this.key = this.el.dataset.key; this.pushEvent("term_look", {}) }
  },
}

// --- the figure viewer: fit, zoom about the cursor, pan. A figure is an <img>
// here — a drawing is its own document — so the viewer handles one shape.
// A box is not one shape: it is two faces of the same piece, and they are
// laid side by side on a single canvas, so a zoom is a zoom of the piece and
// not of a picture of one of its sides — the name band, the crest and the
// type are compared between cover and back without closing anything.
// `faces` says where each one sits in the canvas's own units and which one
// is being looked at: the one the box showed when it was expanded opens
// centred, Fit comes back to it, and ← → walk to the other one.
const viewer = { scale: 1, x: 0, y: 0, w: 0, h: 0, drag: null, faces: null, focus: 0, name: "" }
function viewerEl() {
  let v = document.getElementById("viewer")
  if (v) return v
  v = document.createElement("div"); v.id = "viewer"; v.className = "viewer"; v.setAttribute("role", "dialog"); v.setAttribute("aria-modal", "true"); v.setAttribute("aria-label", "Figure viewer")
  v.innerHTML = `<div class="bar"><span class="title" id="v-title"></span><button class="btn" id="v-out" title="Zoom out (−)">−</button><span class="pct" id="v-pct">100%</span><button class="btn" id="v-in" title="Zoom in (+)">+</button><button class="btn" id="v-100" title="Actual size (0)">1:1</button><button class="btn" id="v-fit" title="Fit (f)">Fit</button><button class="btn" id="v-close" title="Close (Esc)">Close</button></div><div class="stage" id="v-stage"><div class="canvas" id="v-canvas"></div><span class="hint">scroll to zoom · drag to pan · esc to close</span></div>`
  document.body.append(v)
  const $ = s => v.querySelector(s), stage = $("#v-stage"), canvas = $("#v-canvas")
  const apply = () => { canvas.style.width = viewer.w * viewer.scale + "px"; canvas.style.height = viewer.h * viewer.scale + "px"; canvas.style.transform = `translate(${viewer.x}px, ${viewer.y}px)`; $("#v-pct").textContent = Math.round(viewer.scale * 100) + "%" }
  // One face of the canvas, in the canvas's units — the whole of it when
  // there is only ever one, which is what a figure is.
  const face = i => viewer.faces ? viewer.faces[i] : { x: 0, w: viewer.w }
  const said = () => { $("#v-title").textContent = viewer.faces ? `${viewer.name} — ${face(viewer.focus).label}` : viewer.name }
  // Fit and 1:1 measure the face being looked at, not the pair: two faces
  // side by side fitted whole would open every box too far away to read.
  const fit = () => { const st = stage.getBoundingClientRect(), f = face(viewer.focus); viewer.scale = Math.min((st.width - 48) / f.w, (st.height - 48) / viewer.h, 4); viewer.x = st.width / 2 - (f.x + f.w / 2) * viewer.scale; viewer.y = (st.height - viewer.h * viewer.scale) / 2; apply() }
  const zoom = (factor, cx, cy) => { const st = stage.getBoundingClientRect(); if (cx === undefined) { cx = st.width / 2; cy = st.height / 2 } const next = Math.min(8, Math.max(0.1, viewer.scale * factor)); viewer.x = cx - (cx - viewer.x) * (next / viewer.scale); viewer.y = cy - (cy - viewer.y) * (next / viewer.scale); viewer.scale = next; apply() }
  const actual = () => { const st = stage.getBoundingClientRect(), f = face(viewer.focus); viewer.scale = 1; viewer.x = st.width / 2 - (f.x + f.w / 2); viewer.y = (st.height - viewer.h) / 2; apply() }
  // Turning inside the viewer keeps the zoom and the height: the same detail
  // of the other face slides in, which is the whole point of holding both.
  const turn = d => {
    if (!viewer.faces) return
    viewer.focus = (viewer.focus + d + viewer.faces.length) % viewer.faces.length
    const st = stage.getBoundingClientRect(), f = face(viewer.focus)
    viewer.x = st.width / 2 - (f.x + f.w / 2) * viewer.scale; said(); apply()
  }
  const close = () => { v.classList.remove("on"); canvas.replaceChildren(); canvas.classList.remove("pair"); viewer.faces = null }
  const clone = img => { const n = img.cloneNode(true); n.setAttribute("draggable", "false"); n.className = ""; n.style.cssText = ""; return n }
  // Both faces are shown once both are measured: the canvas has one set of
  // units and one of them half-loaded would lay the other one out wrong.
  const loaded = (nodes, show) => {
    let left = nodes.filter(n => !(n.complete && n.naturalWidth)).length
    if (!left) return show()
    for (const n of nodes) if (!(n.complete && n.naturalWidth)) n.onload = n.onerror = () => { if (--left === 0) show() }
  }
  v.open = (img, title) => {
    canvas.replaceChildren(); canvas.classList.remove("pair"); viewer.faces = null; viewer.focus = 0
    const node = clone(img)
    const show = () => { viewer.w = node.naturalWidth || node.width || 800; viewer.h = node.naturalHeight || node.height || 600; canvas.append(node); viewer.name = title; said(); $(".hint").textContent = "scroll to zoom · drag to pan · esc to close"; v.classList.add("on"); fit(); $("#v-close").focus() }
    loaded([node], show)
  }
  // The piece: the faces in the order they are turned, and which one showed.
  v.openPair = (imgs, name, labels, which) => {
    canvas.replaceChildren(); const nodes = imgs.map(clone)
    const show = () => {
      // The faces are brought to one height and set out left to right with a
      // gap of their own; the canvas carries the pair's size, and each face
      // is placed in per cent of it, so the whole layout grows with the zoom.
      const h = Math.max(...nodes.map(n => n.naturalHeight || n.height || 1000))
      const ws = nodes.map(n => (n.naturalWidth || n.width || 700) * h / (n.naturalHeight || n.height || 1000)), gap = h * 0.04
      viewer.h = h; viewer.w = ws.reduce((a, b) => a + b, 0) + gap * (nodes.length - 1); viewer.faces = []
      let x = 0
      nodes.forEach((n, i) => {
        viewer.faces.push({ x, w: ws[i], label: labels[i] })
        n.style.cssText = `position:absolute;top:0;height:100%;left:${x / viewer.w * 100}%;width:${ws[i] / viewer.w * 100}%`
        x += ws[i] + gap
      })
      canvas.classList.add("pair"); canvas.append(...nodes)
      viewer.name = name; viewer.focus = Math.min(Math.max(which, 0), nodes.length - 1); said()
      $(".hint").textContent = "scroll to zoom · drag to pan · ← → turn · esc to close"
      v.classList.add("on"); fit(); $("#v-close").focus()
    }
    loaded(nodes, show)
  }
  $("#v-close").addEventListener("click", close); $("#v-in").addEventListener("click", () => zoom(1.25)); $("#v-out").addEventListener("click", () => zoom(0.8)); $("#v-fit").addEventListener("click", fit); $("#v-100").addEventListener("click", actual)
  stage.addEventListener("wheel", ev => { ev.preventDefault(); const r = stage.getBoundingClientRect(); zoom(ev.deltaY < 0 ? 1.12 : 1 / 1.12, ev.clientX - r.left, ev.clientY - r.top) }, { passive: false })
  stage.addEventListener("dragstart", ev => ev.preventDefault())
  stage.addEventListener("pointerdown", ev => { ev.preventDefault(); viewer.drag = { x: ev.clientX - viewer.x, y: ev.clientY - viewer.y }; stage.classList.add("dragging"); stage.setPointerCapture(ev.pointerId) })
  stage.addEventListener("pointermove", ev => { if (!viewer.drag) return; viewer.x = ev.clientX - viewer.drag.x; viewer.y = ev.clientY - viewer.drag.y; apply() })
  for (const t of ["pointerup", "pointercancel"]) stage.addEventListener(t, () => { viewer.drag = null; stage.classList.remove("dragging") })
  stage.addEventListener("dblclick", ev => { const r = stage.getBoundingClientRect(); zoom(viewer.scale < 1.5 ? 2 : 0.5, ev.clientX - r.left, ev.clientY - r.top) })
  addEventListener("resize", () => { if (v.classList.contains("on")) fit() })
  document.addEventListener("keydown", ev => { if (!v.classList.contains("on")) return; if (ev.key === "Escape") close(); else if (ev.key === "+" || ev.key === "=") zoom(1.25); else if (ev.key === "-") zoom(0.8); else if (ev.key === "0") actual(); else if (ev.key === "f") fit(); else if (ev.key === "ArrowLeft") turn(-1); else if (ev.key === "ArrowRight") turn(1) })
  return v
}
export function openViewer(img, title) { viewerEl().open(img, title) }
export function openViewerPair(imgs, name, labels, which) { viewerEl().openPair(imgs, name, labels, which) }
