// The client owns the reader's arrangement — the rail's width, the
// ground, the clock — and the line editing the server has no business
// in: history and Tab completion on the wb.sh line. Kept in this
// browser (localStorage), never in config.conf.

const store = {
  get(k) { try { return localStorage.getItem(k) } catch (e) { return null } },
  set(k, v) { try { localStorage.setItem(k, v) } catch (e) {} },
}

// --- the wb.sh line: history and completion, as the Assistant Terminal does them
class History {
  constructor(limit = 100) { this.items = []; this.sel = -1; this.limit = limit }
  push(msg) { this.sel = -1; if (!msg.trim()) return; if (this.items[0] !== msg) this.items.unshift(msg); while (this.items.length > this.limit) this.items.pop() }
  next() { this.sel = Math.min(this.sel + 1, this.items.length - 1); return this.sel >= 0 ? this.items[this.sel] : "" }
  prev() { this.sel = Math.max(this.sel - 1, -1); return this.sel >= 0 ? this.items[this.sel] : "" }
}
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
    this.el.addEventListener("keydown", ev => {
      if (ev.key === "Enter") { history.push(this.el.value); /* the form submits */ setTimeout(() => { this.el.value = "" }, 0) }
      else if (ev.key === "ArrowUp") { ev.preventDefault(); this.el.value = history.next() }
      else if (ev.key === "ArrowDown") { ev.preventDefault(); this.el.value = history.prev() }
      else if (ev.key === "Tab") {
        ev.preventDefault()
        this.el.value = completeLine(this.el.value, new Trie(cliWords(words, this.el.value)), msg => toast(msg, 6600))
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
    const height = pane => parseInt(getComputedStyle(pane.querySelector(".out")).maxHeight, 10) || JOB_OUT_DEFAULT
    // Where a drag starts from: the box as drawn, not its cap. The cap
    // is a ceiling a short output never reaches, and a drag that began
    // there moved nothing until the hand had crossed the whole box —
    // past its foot in the tray, past its head on the Jobs screen.
    const drawn = pane => pane.querySelector(".out").getBoundingClientRect().height || height(pane)
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
      const box = el.closest(".out") || el
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

// --- the rail's width: dragged, nudged with the arrows, reset with a double click, kept
const RAIL_KEY = "wb-console-rail", RAIL_MIN = 300, RAIL_MAX_SHARE = 0.5, RAIL_DEFAULT = 380
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
    const saved = store.get(RAIL_KEY)
    setRail(saved ? +saved : RAIL_DEFAULT)
    // The frame the reader chose — the band's side, the rail's — as classes on <body>.
    try { for (const cls of JSON.parse(store.get("wb-console-frame") || "[]")) document.body.classList.add(cls) } catch (e) {}
  },
  updated() { this.again && this.again() },
  destroyed() { removeEventListener("resize", this.resize) },
}

let toastTimer = null
export function toast(text, ms = 2200) {
  let t = document.getElementById("toast")
  if (!t) { t = document.createElement("div"); t.id = "toast"; t.className = "toast"; document.body.append(t) }
  t.textContent = text; t.classList.add("on")
  clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove("on"), ms)
}

// --- the logs: the server pushes lines, the hook keeps and filters them ------
// Two thousand lines and a search box: filtering on the server would
// re-render them all across the socket on every keystroke.
const SVC_COLORS = ["app", "database", "pgadmin", "network", "balancer", "migrate"]
const svcColor = s => { const base = s.replace(/\d+$/, ""); return SVC_COLORS.includes(base) ? `var(--svc-${base})` : "var(--svc-network)" }
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
    const renderChips = () => {
      const chips = $("#svc-chips"); chips.replaceChildren()
      for (const s of Object.keys(logs.services)) {
        const b = h("button", "btn svc", s); b.type = "button"; b.style.setProperty("--svc", svcColor(s)); b.setAttribute("aria-pressed", String(logs.services[s] !== false))
        b.addEventListener("click", () => { logs.services[s] = !(logs.services[s] !== false); b.setAttribute("aria-pressed", String(logs.services[s])); rerender() })
        chips.append(b)
      }
    }
    const rerender = () => {
      box.replaceChildren()
      box.classList.toggle("no-svc", Object.keys(logs.services).filter(s => logs.services[s] !== false).length === 1)
      const vis = logs.all.filter(passes)
      for (const l of vis) box.append(lineEl(l))
      if (!vis.length) box.append(h("div", "nothing", logs.all.length ? "Nothing matches: every line is filtered out." : "No lines yet: the stream is attached and waiting for the containers to write one."))
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
      else if (a.getAttribute("href")?.startsWith("#")) {
        ev.preventDefault()
        const id = a.getAttribute("href").slice(1)
        const target = id === "top" ? this.el.querySelector(".md") : document.getElementById(id)
        if (target) target.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth", block: "start" })
      }
    })
  },
}

// --- the box in hand: a click turns it (phx-click on the face; Enter is
// phx-keydown, Space is the browser's own for a button and is given here),
// and the lozenge in its corner opens the viewer on the side that shows.
// The lozenge stops its click before the document, where LiveView listens
// for the face's.
export const Face = {
  mounted() {
    this.el.addEventListener("keydown", ev => { if (ev.key === " " && ev.target === this.el) { ev.preventDefault(); this.el.click() } })
    this.el.querySelector(".expand").addEventListener("click", ev => {
      ev.stopPropagation()
      const back = this.el.querySelector(".card").classList.contains("back")
      const img = this.el.querySelector(back ? ".side.back img" : ".side.front img")
      if (img) openViewer(img, img.alt || (back ? "The back of the box" : "The box"))
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
// The pictogram of one frame: the band, the rail, the screen, with the
// axis being chosen drawn full and the rest faint. A segment of the
// control shows the frame it would set, so every position is in view
// and the one in force is the pressed one — no ghost, no sentence.
function pict(state, axis) {
  const { bottom, right, off } = state, top = bottom ? 5 : 5.5, hgt = 9.5, rx = right ? 17 : 1.5
  const bar = (y, c) => `<rect class="${c}" x="1" y="${y}" width="24" height="3" rx="1"/>`
  const col = (x, c) => `<rect class="${c}" x="${x}" y="${top}" width="7.5" height="${hgt}" rx="1"/>`
  const band = bar(bottom ? 15 : 1, axis === "band" ? "r" : "f")
  const rail = axis === "rail" ? col(rx, off ? "d" : "r") : (off ? "" : col(rx, "f"))
  const scr = `<rect class="o" x="${off ? 1.5 : (right ? 1.5 : 10)}" y="${top}" width="${off ? 23 : 14.5}" height="${hgt}" rx="1"/>`
  return `<svg viewBox="0 0 26 19" aria-hidden="true">${band}${rail}${scr}</svg>`
}
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
// fallback — so "the house's" is the properties absent, and each surface
// keeps the size and leading it was drawn at. A face brings its sizes:
// Tamzen is a bitmap face, one drawing per size, and the drawing is the
// family name; the vector faces take any. The leading is unitless, a
// ratio of the size, so it holds when the size changes.
const GROUPS = { code: "wb-console-code", file: "wb-console-file" }
const SIZES = [10, 11, 12, 13, 14, 15, 16, 18, 20]
const LEADINGS = [1, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2]
const FACES = {
  house: { name: "The house's — IBM Plex Mono", sizes: SIZES, family: () => null },
  fira: { name: "Fira Code", sizes: SIZES, family: () => '"Fira Code"', note: "Ligatures on. SIL Open Font License." },
  vga: { name: "Flexi IBM VGA", sizes: [14, 16, 18, 20, 24, 32], family: () => '"Flexi IBM VGA True"', note: "The PC's text mode, by VileR. CC BY-SA 4.0." },
  tamzen: { name: "Tamzen", sizes: [9, 12, 13, 14, 15, 16, 20], family: s => `"Tamzen${{ 9: 5, 12: 6, 13: 7, 14: 7, 15: 8, 16: 8, 20: 10 }[s]}x${s}"`, note: "A bitmap face by Scott Fial: one drawing per size, so the sizes are its own." },
}
const usual = f => f.sizes[Math.floor(f.sizes.length / 2)]
const choiceOf = group => { try { const c = JSON.parse(store.get(GROUPS[group]) || "{}"); return { face: c.face in FACES ? c.face : "house", size: c.size || null, leading: LEADINGS.includes(c.leading) ? c.leading : null } } catch (e) { return { face: "house", size: null, leading: null } } }
function applyChoice(group, { face, size, leading }) {
  const root = document.documentElement.style, f = FACES[face]
  const s = f.sizes.includes(size) ? size : (face === "house" ? null : usual(f))
  const family = f.family(s || usual(f))
  if (family) root.setProperty(`--${group}-face`, family); else root.removeProperty(`--${group}-face`)
  if (s) root.setProperty(`--${group}-size`, `${s}px`); else root.removeProperty(`--${group}-size`)
  if (leading) root.setProperty(`--${group}-leading`, String(leading)); else root.removeProperty(`--${group}-leading`)
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
    sizeSel.replaceChildren(opt("", choice.face === "house" ? "as drawn" : "its usual", !choice.size), ...f.sizes.map(n => opt(n, `${n} px`, n === choice.size)))
    leadSel.replaceChildren(opt("", "as drawn", !choice.leading), ...LEADINGS.map(n => opt(n, n.toFixed(1), n === choice.leading)))
    if (note) note.textContent = f.note || "IBM Plex Mono, the house's code face, at each surface's own size."
  }
  const keep = () => { choice = applyChoice(group, choice); store.set(GROUPS[group], JSON.stringify(choice)); draw() }
  faceSel.addEventListener("change", () => { choice = { ...choice, face: faceSel.value, size: null }; keep() })
  sizeSel.addEventListener("change", () => { choice = { ...choice, size: sizeSel.value ? Number(sizeSel.value) : null }; keep() })
  leadSel.addEventListener("change", () => { choice = { ...choice, leading: leadSel.value ? Number(leadSel.value) : null }; keep() })
  draw()
}

// --- the colours: the twelve rules of console/elixir_color_theme.jsonc,
// each a property on the root the `.src` surfaces read, kept in this
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
const HOUSE = { dark: "One Dark", light: "One Light" }
const KEYS = ["base", "punct", "comment", "atom", "const", "func", "kw", "op", "mod", "str", "interp", "regex"]
const LANGS = {
  elixir: { name: "Elixir and its templates", roles: [
    { key: "base", name: "code", scopes: ["source.elixir"] },
    { key: "punct", name: "brackets", scopes: ["punctuation.section.scope.elixir", "punctuation.section.array.elixir", "punctuation.section.function.elixir", "punctuation.section.list.begin.elixir", "punctuation.section.list.end.elixir"] },
    { key: "comment", name: "comments", scopes: ["punctuation.definition.comment.elixir", "comment.line.number-sign.elixir", "comment.unused.elixir", "comment.documentation.heredoc.elixir"], style: "italic" },
    { key: "atom", name: "atoms", scopes: ["constant.character.escape.elixir", "constant.other.symbol.elixir"] },
    { key: "const", name: "constants, numbers", scopes: ["punctuation.definition.constant.elixir", "constant.language.elixir", "constant.numeric.elixir"] },
    { key: "func", name: "functions", scopes: ["entity.name.function.elixir"] },
    { key: "kw", name: "keywords", scopes: ["keyword.control.module.elixir", "keyword.control.elixir", "variable.other.anonymous.elixir"] },
    { key: "op", name: "operators", scopes: ["keyword.operator.other.elixir", "keyword.operator.assignment.elixir", "keyword.operator.logical.elixir", "keyword.operator.comparison.elixir", "keyword.operator.arithmetic.elixir", "punctuation.separator.object.elixir", "punctuation.separator.method.elixir", "parameter.variable.function.elixir"] },
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
// A jsonc is JSON with comments and trailing commas; VS Code's settings
// carry the rules under editor.tokenColorCustomizations.textMateRules, a
// theme file under tokenColors, and a bare array is taken as the rules.
function parseJsonc(text) {
  const bare = text.replace(/("(?:[^"\\]|\\.)*")|\/\*[\s\S]*?\*\/|\/\/[^\n]*/g, (m, str) => str || "").replace(/,(\s*[}\]])/g, "$1")
  const doc = JSON.parse(bare)
  const rules = Array.isArray(doc) ? doc : doc.tokenColors || (doc["editor.tokenColorCustomizations"] || doc).textMateRules
  if (!Array.isArray(rules)) throw new Error("no textMateRules, no tokenColors")
  return rules
}
// A rule's scope covers a role's when it is the same, or a parent of it.
const covers = (rule, scope) => scope === rule || scope.startsWith(rule + ".")
// The rules, sorted into languages: `{elixir: {kw: "#..."}, json: {...}}`.
function coloursFromRules(rules) {
  const out = {}
  for (const r of rules) {
    const fg = r.settings && r.settings.foreground
    if (!fg || !HEX.test(fg)) continue
    const scopes = (Array.isArray(r.scope) ? r.scope : String(r.scope || "").split(",")).map(x => x.trim()).filter(Boolean)
    for (const [l, lang] of Object.entries(LANGS)) for (const role of lang.roles) if (scopes.some(rs => role.scopes.some(ts => covers(rs, ts)))) (out[l] ||= {})[role.key] = fg.toLowerCase()
  }
  return out
}
const asJsonc = () => JSON.stringify({ "editor.tokenColorCustomizations": { textMateRules: Object.entries(LANGS).flatMap(([l, lang]) => lang.roles.map(role => ({ scope: role.scopes.length === 1 ? role.scopes[0] : role.scopes, settings: { ...(role.style ? { fontStyle: role.style } : {}), foreground: shownColour(l, role.key) } }))) } }, null, 2)
function bindColours(el) {
  const swatches = el.querySelector("#swatches"), area = el.querySelector("#jsonc"), word = el.querySelector("#jsonc-word"), reset = el.querySelector("#jsonc-reset"), which = el.querySelector("#colours-ground"), langSel = el.querySelector("#colours-lang")
  if (!swatches || !area || !langSel) return
  let all = coloursOf(), lang = "elixir"
  const mine = () => (all[ground()] || {})[lang] || {}
  const say = (text, bad) => { if (word) { word.textContent = text; word.classList.toggle("bad", !!bad) } }
  const set = c => { const g = ground(); all = { ...all, [g]: { ...(all[g] || {}), [lang]: c } }; applyColours(all) }
  const merge = found => { const g = ground(), was = all[g] || {}; all = { ...all, [g]: Object.fromEntries(Object.keys(LANGS).map(l => [l, { ...(was[l] || {}), ...(found[l] || {}) }])) }; applyColours(all) }
  const keep = () => { store.set(COLOURS_KEY, JSON.stringify(all)); draw() }
  langSel.replaceChildren(...Object.entries(LANGS).map(([l, v]) => { const o = document.createElement("option"); o.value = l; o.textContent = v.name; return o }))
  const draw = () => {
    const g = ground()
    langSel.value = lang
    for (const s of el.querySelectorAll(".sample[data-lang]")) s.hidden = s.dataset.lang !== lang
    if (which) which.textContent = `the ${g} ground's, for ${LANGS[lang].name} — ${HOUSE[g]} underneath`
    if (reset) reset.textContent = `Back to ${HOUSE[g]}`
    swatches.replaceChildren(...LANGS[lang].roles.map(role => {
      const label = document.createElement("label"), input = document.createElement("input"), name = document.createElement("span"), own = document.createElement("small")
      input.type = "color"; input.value = shownColour(lang, role.key); input.setAttribute("aria-label", `${role.name}, the colour`)
      input.addEventListener("input", () => { set({ ...mine(), [role.key]: input.value.toLowerCase() }); own.textContent = "·" })
      input.addEventListener("change", () => { store.set(COLOURS_KEY, JSON.stringify(all)); say("") })
      name.textContent = role.name; own.textContent = mine()[role.key] ? "·" : ""; own.title = "set by you"
      label.append(input, name, own); return label
    }))
  }
  langSel.addEventListener("change", () => { lang = langSel.value in LANGS ? langSel.value : "elixir"; say(""); draw() })
  el.querySelector("#jsonc-apply")?.addEventListener("click", () => {
    try {
      const found = coloursFromRules(parseJsonc(area.value))
      const n = Object.values(found).reduce((a, c) => a + Object.keys(c).length, 0)
      if (!n) return say("no rule of it covers any role of any language", true)
      merge(found); keep(); say(`${n} rules taken, for the ${ground()} ground: ${Object.keys(found).map(l => `${Object.keys(found[l]).length} ${l}`).join(", ")}`)
    } catch (e) { say(`not read: ${e.message}`, true) }
  })
  el.querySelector("#jsonc-show")?.addEventListener("click", () => { area.value = asJsonc(); say(`the ${ground()} ground's palettes, every language, as VS Code reads them — copy them out`); area.focus(); area.select() })
  reset?.addEventListener("click", () => { set({}); keep(); say(`${HOUSE[ground()]} for ${LANGS[lang].name}, as it came`) })
  onGround(() => { all = coloursOf(); draw() })
  draw()
}

export const Frame = {
  mounted() {
    const el = this.el, body = document.body, mini = el.querySelector("#mini")
    const state = () => ({ bottom: body.classList.contains("band-bottom"), right: body.classList.contains("rail-right"), off: body.classList.contains("rail-off") })
    const paint = () => {
      const s = state()
      for (const b of el.querySelectorAll(".seg button[data-pick]")) {
        const want = PICKS[b.dataset.pick], on = Object.entries(want).every(([k, v]) => s[k] === v) && (b.dataset.pick !== "left" && b.dataset.pick !== "right" || !s.off)
        b.setAttribute("aria-pressed", String(on))
        if (!b.querySelector("svg")) b.insertAdjacentHTML("afterbegin", pict({ ...s, ...want }, b.closest(".seg").dataset.axis))
      }
      if (mini) { mini.classList.toggle("bottom", s.bottom); mini.classList.toggle("right", s.right); mini.classList.toggle("off", s.off) }
      const chosen = store.get(THEME_KEY) || "system"
      for (const c of el.querySelectorAll(".card[data-ground]")) c.setAttribute("aria-pressed", String(c.dataset.ground === chosen))
    }
    const setFrame = want => {
      const s = { ...state(), ...want }
      body.classList.toggle("band-bottom", s.bottom); body.classList.toggle("rail-right", s.right); body.classList.toggle("rail-off", s.off)
      store.set("wb-console-frame", JSON.stringify(FRAME_CLASSES.filter(c => body.classList.contains(c))))
      paint(); dispatchEvent(new Event("resize"))
    }
    for (const b of el.querySelectorAll(".seg button[data-pick]")) b.addEventListener("click", () => setFrame(PICKS[b.dataset.pick]))
    // The miniature is a control too: the band moves, the rail changes side.
    mini?.querySelector(".mband")?.addEventListener("click", () => setFrame({ bottom: !state().bottom }))
    mini?.querySelector(".mrail")?.addEventListener("click", () => setFrame({ right: !state().right }))
    // The ground: light, dark, or the machine's — which is no choice kept, the way the page boots.
    for (const c of el.querySelectorAll(".card[data-ground]")) c.addEventListener("click", () => {
      const g = c.dataset.ground
      if (g === "system") { try { localStorage.removeItem(THEME_KEY) } catch (e) {} document.documentElement.removeAttribute("data-theme") }
      else { document.documentElement.setAttribute("data-theme", g); store.set(THEME_KEY, g) }
      paint(); document.getElementById("ground-toggle")?.dispatchEvent(new Event("repaint"))
    })
    onGround(paint)
    // The jsonc's fold: the house's caret is drawn from aria-expanded.
    for (const d of el.querySelectorAll("details.disc")) d.addEventListener("toggle", () => d.querySelector("summary.fold")?.setAttribute("aria-expanded", String(d.open)))
    for (const g of Object.keys(GROUPS)) bindPicks(el, g)
    bindColours(el)
    paint()
    // The miniature's terminal follows its end, as the Logs screen does.
    const lines = mini?.querySelector(".lines"); if (lines) lines.scrollTop = lines.scrollHeight
  },
}

// --- the terminal: the server pushes the session's lines, the input keeps its history.
export const Term = {
  mounted() {
    const screen = this.el.querySelector("#term-screen"), history = new History()
    const line = (html, cls) => { const d = document.createElement("div"); if (cls) d.className = cls; d.innerHTML = html; screen.append(d); while (screen.children.length > 2000) screen.firstChild.remove(); screen.scrollTop = screen.scrollHeight }
    this.handleEvent("term_out", ({ line: html, dim, prompt, clear }) => { if (clear) screen.replaceChildren(); line(html, dim ? "dim" : prompt ? "p" : "") })
    const bind = () => {
      const input = this.el.querySelector("#term-input"); if (!input || input.dataset.bound) return
      input.dataset.bound = "1"
      input.addEventListener("keydown", ev => {
        if (ev.key === "Enter") { history.push(input.value); setTimeout(() => { input.value = "" }, 0) }
        else if (ev.key === "ArrowUp") { ev.preventDefault(); input.value = history.next() }
        else if (ev.key === "ArrowDown") { ev.preventDefault(); input.value = history.prev() }
        else if (ev.key === "l" && ev.ctrlKey) { ev.preventDefault(); screen.replaceChildren() }
        else if (ev.key === "PageUp") { ev.preventDefault(); screen.scrollTop -= screen.clientHeight * 0.8 }
        else if (ev.key === "PageDown") { ev.preventDefault(); screen.scrollTop += screen.clientHeight * 0.8 }
      })
      input.focus()
    }
    bind(); this.bind = bind
  },
  updated() { this.bind() },
}

// --- the figure viewer: fit, zoom about the cursor, pan. A figure is an <img>
// here — a drawing is its own document — so the viewer handles one shape.
const viewer = { scale: 1, x: 0, y: 0, w: 0, h: 0, drag: null }
function viewerEl() {
  let v = document.getElementById("viewer")
  if (v) return v
  v = document.createElement("div"); v.id = "viewer"; v.className = "viewer"; v.setAttribute("role", "dialog"); v.setAttribute("aria-modal", "true"); v.setAttribute("aria-label", "Figure viewer")
  v.innerHTML = `<div class="bar"><span class="title" id="v-title"></span><button class="btn" id="v-out" title="Zoom out (−)">−</button><span class="pct" id="v-pct">100%</span><button class="btn" id="v-in" title="Zoom in (+)">+</button><button class="btn" id="v-100" title="Actual size (0)">1:1</button><button class="btn" id="v-fit" title="Fit (f)">Fit</button><button class="btn" id="v-close" title="Close (Esc)">Close</button></div><div class="stage" id="v-stage"><div class="canvas" id="v-canvas"></div><span class="hint">scroll to zoom · drag to pan · esc to close</span></div>`
  document.body.append(v)
  const $ = s => v.querySelector(s), stage = $("#v-stage"), canvas = $("#v-canvas")
  const apply = () => { canvas.style.width = viewer.w * viewer.scale + "px"; canvas.style.height = viewer.h * viewer.scale + "px"; canvas.style.transform = `translate(${viewer.x}px, ${viewer.y}px)`; $("#v-pct").textContent = Math.round(viewer.scale * 100) + "%" }
  const fit = () => { const st = stage.getBoundingClientRect(); viewer.scale = Math.min((st.width - 48) / viewer.w, (st.height - 48) / viewer.h, 4); viewer.x = (st.width - viewer.w * viewer.scale) / 2; viewer.y = (st.height - viewer.h * viewer.scale) / 2; apply() }
  const zoom = (factor, cx, cy) => { const st = stage.getBoundingClientRect(); if (cx === undefined) { cx = st.width / 2; cy = st.height / 2 } const next = Math.min(8, Math.max(0.1, viewer.scale * factor)); viewer.x = cx - (cx - viewer.x) * (next / viewer.scale); viewer.y = cy - (cy - viewer.y) * (next / viewer.scale); viewer.scale = next; apply() }
  const actual = () => { const st = stage.getBoundingClientRect(); viewer.scale = 1; viewer.x = (st.width - viewer.w) / 2; viewer.y = (st.height - viewer.h) / 2; apply() }
  const close = () => { v.classList.remove("on"); canvas.replaceChildren() }
  v.open = (img, title) => {
    canvas.replaceChildren(); const node = img.cloneNode(true); node.setAttribute("draggable", "false"); node.className = ""
    const show = () => { viewer.w = node.naturalWidth || node.width || 800; viewer.h = node.naturalHeight || node.height || 600; canvas.append(node); $("#v-title").textContent = title; v.classList.add("on"); fit(); $("#v-close").focus() }
    if (node.complete && node.naturalWidth) show(); else { node.onload = show; if (node.complete) show() }
  }
  $("#v-close").addEventListener("click", close); $("#v-in").addEventListener("click", () => zoom(1.25)); $("#v-out").addEventListener("click", () => zoom(0.8)); $("#v-fit").addEventListener("click", fit); $("#v-100").addEventListener("click", actual)
  stage.addEventListener("wheel", ev => { ev.preventDefault(); const r = stage.getBoundingClientRect(); zoom(ev.deltaY < 0 ? 1.12 : 1 / 1.12, ev.clientX - r.left, ev.clientY - r.top) }, { passive: false })
  stage.addEventListener("dragstart", ev => ev.preventDefault())
  stage.addEventListener("pointerdown", ev => { ev.preventDefault(); viewer.drag = { x: ev.clientX - viewer.x, y: ev.clientY - viewer.y }; stage.classList.add("dragging"); stage.setPointerCapture(ev.pointerId) })
  stage.addEventListener("pointermove", ev => { if (!viewer.drag) return; viewer.x = ev.clientX - viewer.drag.x; viewer.y = ev.clientY - viewer.drag.y; apply() })
  for (const t of ["pointerup", "pointercancel"]) stage.addEventListener(t, () => { viewer.drag = null; stage.classList.remove("dragging") })
  stage.addEventListener("dblclick", ev => { const r = stage.getBoundingClientRect(); zoom(viewer.scale < 1.5 ? 2 : 0.5, ev.clientX - r.left, ev.clientY - r.top) })
  addEventListener("resize", () => { if (v.classList.contains("on")) fit() })
  document.addEventListener("keydown", ev => { if (!v.classList.contains("on")) return; if (ev.key === "Escape") close(); else if (ev.key === "+" || ev.key === "=") zoom(1.25); else if (ev.key === "-") zoom(0.8); else if (ev.key === "0") actual(); else if (ev.key === "f") fit() })
  return v
}
export function openViewer(img, title) { viewerEl().open(img, title) }
