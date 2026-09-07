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

// --- how tall a job's output is allowed to be. A grip under each pane,
// made like the rail's: it moves a variable, one per job, kept in this
// browser under the job's id; config.conf never hears about it. The
// variable and not a height, because `.out` reads it with the default
// in the fallback — a job that was never dragged has nothing written
// on it, and a double-click takes it back to that.
// The browser's own `resize` did this first: its grip sits in the
// corner where the scrollbar ends, and that corner is the browser's to
// paint — a white square on a terminal ground, and only ever when the
// output was long enough to scroll.
const JOB_OUT_KEY = "wb-console-job-out", JOB_OUT_MIN = 80, JOB_OUT_DEFAULT = 220
export const JobOut = {
  mounted() {
    // What each job's own grip was left at, by job id. A job that was
    // never dragged is not in here at all and takes the default from
    // the stylesheet — which is also what a double-click gives back.
    let tall = {}
    try { tall = JSON.parse(store.get(JOB_OUT_KEY) || "{}") || {} } catch (_) { tall = {} }

    const cap = () => Math.max(JOB_OUT_MIN, Math.round(innerHeight * 0.8))
    const height = job => parseInt(getComputedStyle(job.querySelector(".out")).maxHeight, 10) || JOB_OUT_DEFAULT
    const label = (job, h) => {
      const g = job.querySelector(".ograb")
      if (!g) return
      g.setAttribute("aria-valuenow", String(h))
      g.setAttribute("aria-valuemin", String(JOB_OUT_MIN))
      g.setAttribute("aria-valuemax", String(cap()))
      g.title = `${h}px — drag, or arrow keys; double-click for ${JOB_OUT_DEFAULT}`
    }
    const set = (job, px) => {
      const h = Math.round(Math.min(cap(), Math.max(JOB_OUT_MIN, px)))
      tall[job.dataset.id] = h
      job.style.setProperty("--job-out", h + "px")
      label(job, h)
      return h
    }
    const forget = job => {
      delete tall[job.dataset.id]
      job.style.removeProperty("--job-out")
      label(job, height(job))
    }
    const keep = () => store.set(JOB_OUT_KEY, JSON.stringify(tall))

    // A patch wipes the inline variable, so it is written again — and
    // this is also where a job that has left the list is forgotten.
    this.paint = () => {
      const live = {}
      for (const job of this.el.querySelectorAll(".job[data-id]")) {
        const id = job.dataset.id
        if (id in tall) {
          live[id] = tall[id]
          job.style.setProperty("--job-out", tall[id] + "px")
        }
        label(job, height(job))
      }
      tall = live
    }
    this.paint()

    // Delegated: every open job carries a grip, and each moves its own.
    this.el.addEventListener("pointerdown", ev => {
      const grip = ev.target.closest(".ograb")
      if (!grip) return
      const job = grip.closest(".job")
      ev.preventDefault()
      grip.setPointerCapture(ev.pointerId)
      grip.classList.add("dragging")
      const from = height(job) - ev.clientY
      const move = e => set(job, e.clientY + from)
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
      forget(grip.closest(".job")); keep()
    })

    this.el.addEventListener("keydown", ev => {
      const grip = ev.target.closest(".ograb")
      if (!grip) return
      const job = grip.closest(".job"), step = ev.shiftKey ? 48 : 16
      if (ev.key === "ArrowUp") set(job, height(job) - step)
      else if (ev.key === "ArrowDown") set(job, height(job) + step)
      else if (ev.key === "Home") forget(job)
      else return
      ev.preventDefault(); keep()
    })

    // A narrower window lowers the ceiling; what was over it comes down.
    this.resize = () => {
      for (const job of this.el.querySelectorAll(".job[data-id]")) {
        if (job.dataset.id in tall) set(job, tall[job.dataset.id])
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
const FRAME = {
  "band-bottom": { on: "The band is at the bottom — click to put it back on top", off: "The band is on top — click to move it to the bottom" },
  "rail-right": { on: "The rail is on the right — click to move it to the left", off: "The rail is on the left — click to move it to the right" },
  "rail-off": { on: "The rail is hidden — click to bring it back", off: "The rail is shown — click to hide it" },
}
function frameIcon(btn, axis) {
  const b = document.body, bottom = b.classList.contains("band-bottom"), right = b.classList.contains("rail-right"), off = b.classList.contains("rail-off")
  const top = bottom ? 5 : 5.5, hgt = 9.5, rx = right ? 17 : 1.5
  const bar = (y, c) => `<rect class="${c}" x="1" y="${y}" width="24" height="3" rx="1"/>`
  const col = (x, c) => `<rect class="${c}" x="${x}" y="${top}" width="7.5" height="${hgt}" rx="1"/>`
  let band = bar(bottom ? 15 : 1, axis === "band" ? "r" : "f")
  if (axis === "band") band += bar(bottom ? 1 : 15, "g")
  let rail = ""
  if (axis === "rail") rail = (off ? "" : col(rx, "r")) + col(right ? 1.5 : 17, "g")
  else if (axis === "off") rail = off ? col(rx, "d") : col(rx, "r")
  else if (!off) rail = col(rx, "f")
  const scr = `<rect class="o" x="${off ? 1.5 : (right ? 1.5 : 10)}" y="${top}" width="${off ? 23 : 14.5}" height="${hgt}" rx="1"/>`
  btn.innerHTML = `<svg viewBox="0 0 26 19" aria-hidden="true">${band}${rail}${scr}</svg>`
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
// reads on the dark terminal is lost on paper: the reader's dark set
// rides over One Dark, the light set over One Light, and the ground's
// change swaps them. The scopes are the jsonc's own, so a VS Code theme
// pastes in — its rules are matched to the twelve by scope, as an editor
// matches them: equal, or a parent of it — and this palette reads back
// out in the same shape, to carry to VS Code.
const COLOURS_KEY = "wb-console-colours"
const HOUSE = { dark: "One Dark", light: "One Light" }
const TOKENS = [
  { key: "base", name: "code", scopes: ["source.elixir"] },
  { key: "punct", name: "brackets", scopes: ["punctuation.section.scope.elixir", "punctuation.section.array.elixir", "punctuation.section.function.elixir", "punctuation.section.list.begin.elixir", "punctuation.section.list.end.elixir"] },
  { key: "comment", name: "comments", scopes: ["punctuation.definition.comment.elixir", "comment.line.number-sign.elixir", "comment.unused.elixir", "comment.documentation.heredoc.elixir"], style: "italic" },
  { key: "atom", name: "atoms", scopes: ["constant.character.escape.elixir", "constant.other.symbol.elixir"] },
  { key: "const", name: "constants", scopes: ["punctuation.definition.constant.elixir", "constant.language.elixir", "constant.numeric.elixir"] },
  { key: "func", name: "functions", scopes: ["entity.name.function.elixir"] },
  { key: "kw", name: "keywords", scopes: ["keyword.control.module.elixir", "keyword.control.elixir", "variable.other.anonymous.elixir"] },
  { key: "op", name: "operators", scopes: ["keyword.operator.other.elixir", "keyword.operator.assignment.elixir", "keyword.operator.logical.elixir", "keyword.operator.comparison.elixir", "keyword.operator.arithmetic.elixir", "punctuation.separator.object.elixir", "punctuation.separator.method.elixir", "parameter.variable.function.elixir"] },
  { key: "mod", name: "modules", scopes: ["variable.other.constant.elixir", "entity.name.type.module.elixir"] },
  { key: "str", name: "strings", scopes: ["punctuation.definition.string.begin.elixir", "punctuation.definition.string.end.elixir", "string.quoted.double.elixir", "support.function.variable.quoted.single.elixir", "string.quoted.double.interpolated.elixir", "string.quoted.double.literal.elixir"] },
  { key: "interp", name: "embedded", scopes: ["punctuation.section.embedded.elixir", "keyword.other.special-method.elixir", "punctuation.definition.variable.elixir", "variable.other.readwrite.module.elixir", "variable.language.elixir"] },
  { key: "regex", name: "regex", scopes: ["punctuation.section.regexp.begin.elixir", "punctuation.section.regexp.end.elixir", "string.regexp.interpolated.elixir", "string.regexp.group.elixir", "string.regexp.character-class.elixir", "string.regexp.arbitrary-repitition.elixir"] },
]
const HEX = /^#[0-9a-f]{6}$/i
// What is kept: `{dark: {...}, light: {...}}`. A flat map is the shape
// of the first days, when there was one ground for code: it was dark's.
const clean = c => Object.fromEntries(TOKENS.filter(t => HEX.test((c || {})[t.key] || "")).map(t => [t.key, c[t.key].toLowerCase()]))
const coloursOf = () => { try { const c = JSON.parse(store.get(COLOURS_KEY) || "{}"); return c.dark || c.light ? { dark: clean(c.dark), light: clean(c.light) } : { dark: clean(c), light: {} } } catch (e) { return { dark: {}, light: {} } } }
function applyColours(all) {
  const root = document.documentElement.style, c = all[ground()] || {}
  for (const t of TOKENS) { if (c[t.key]) root.setProperty(`--t-${t.key}`, c[t.key]); else root.removeProperty(`--t-${t.key}`) }
}
applyColours(coloursOf())
// The ground changes under the palette — the toggle, or the machine —
// and the other set goes on; whoever draws swatches listens too.
const onGround = f => { new MutationObserver(f).observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme"] }); matchMedia("(prefers-color-scheme: dark)").addEventListener("change", f) }
onGround(() => applyColours(coloursOf()))
// The colour each token shows now: the reader's, or the stylesheet's.
const shownColour = key => getComputedStyle(document.documentElement).getPropertyValue(`--t-${key}`).trim().toLowerCase()
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
// A rule's scope covers a token's when it is the same, or a parent of it.
const covers = (rule, scope) => scope === rule || scope.startsWith(rule + ".")
function coloursFromRules(rules) {
  const c = {}
  for (const r of rules) {
    const fg = r.settings && r.settings.foreground
    if (!fg || !HEX.test(fg)) continue
    const scopes = Array.isArray(r.scope) ? r.scope : String(r.scope || "").split(",")
    for (const t of TOKENS) if (scopes.some(rs => t.scopes.some(ts => covers(rs.trim(), ts)))) c[t.key] = fg.toLowerCase()
  }
  return c
}
const asJsonc = () => JSON.stringify({ "editor.tokenColorCustomizations": { textMateRules: TOKENS.map(t => ({ scope: t.scopes.length === 1 ? t.scopes[0] : t.scopes, settings: { ...(t.style ? { fontStyle: t.style } : {}), foreground: shownColour(t.key) } })) } }, null, 2)
function bindColours(el) {
  const swatches = el.querySelector("#swatches"), area = el.querySelector("#jsonc"), word = el.querySelector("#jsonc-word"), reset = el.querySelector("#jsonc-reset"), which = el.querySelector("#colours-ground")
  if (!swatches || !area) return
  let all = coloursOf()
  const mine = () => all[ground()] || {}
  const say = (text, bad) => { if (word) { word.textContent = text; word.classList.toggle("bad", !!bad) } }
  const set = c => { all = { ...all, [ground()]: c }; applyColours(all) }
  const keep = () => { store.set(COLOURS_KEY, JSON.stringify(all)); draw() }
  const draw = () => {
    const g = ground()
    if (which) which.textContent = `the ${g} ground's — ${HOUSE[g]} underneath`
    if (reset) reset.textContent = `Back to ${HOUSE[g]}`
    swatches.replaceChildren(...TOKENS.map(t => {
      const label = document.createElement("label"), input = document.createElement("input"), name = document.createElement("span"), own = document.createElement("small")
      input.type = "color"; input.value = shownColour(t.key); input.setAttribute("aria-label", `${t.name}, the colour`)
      input.addEventListener("input", () => { set({ ...mine(), [t.key]: input.value.toLowerCase() }); own.textContent = "·" })
      input.addEventListener("change", () => { store.set(COLOURS_KEY, JSON.stringify(all)); say("") })
      name.textContent = t.name; own.textContent = mine()[t.key] ? "·" : ""; own.title = "set by you"
      label.append(input, name, own); return label
    }))
  }
  el.querySelector("#jsonc-apply")?.addEventListener("click", () => {
    try {
      const found = coloursFromRules(parseJsonc(area.value))
      const n = Object.keys(found).length
      if (!n) return say("no rule of it covers any of the twelve", true)
      set({ ...mine(), ...found }); keep(); say(`${n} of 12 taken, for the ${ground()} ground`)
    } catch (e) { say(`not read: ${e.message}`, true) }
  })
  el.querySelector("#jsonc-show")?.addEventListener("click", () => { area.value = asJsonc(); say(`the ${ground()} ground's palette, as VS Code reads it — copy it out`); area.focus(); area.select() })
  reset?.addEventListener("click", () => { set({}); keep(); say(`${HOUSE[ground()]}, as it came`) })
  onGround(() => { all = coloursOf(); draw() })
  draw()
}

export const Frame = {
  mounted() {
    const paint = () => {
      for (const btn of this.el.querySelectorAll("button.frame")) {
        const cls = btn.dataset.frame, on = document.body.classList.contains(cls)
        btn.setAttribute("aria-pressed", String(on))
        btn.title = FRAME[cls][on ? "on" : "off"]
        const help = this.el.querySelector(`[data-help="${cls}"]`); if (help) help.textContent = btn.title
        frameIcon(btn, btn.dataset.axis)
      }
      const t = ground(), say = t === "dark" ? "Dark ground — click for light" : "Light ground — click for dark"
      const g = this.el.querySelector("#theme"); if (g) { g.setAttribute("aria-pressed", String(t === "dark")); g.title = say }
      const h = this.el.querySelector("#help-theme"); if (h) h.textContent = say
    }
    for (const btn of this.el.querySelectorAll("button.frame")) btn.addEventListener("click", () => {
      document.body.classList.toggle(btn.dataset.frame)
      store.set("wb-console-frame", JSON.stringify(Object.keys(FRAME).filter(c => document.body.classList.contains(c))))
      paint(); dispatchEvent(new Event("resize"))
    })
    this.el.querySelector("#theme")?.addEventListener("click", () => { const t = ground() === "dark" ? "light" : "dark"; document.documentElement.setAttribute("data-theme", t); store.set(THEME_KEY, t); paint(); document.getElementById("ground-toggle")?.dispatchEvent(new Event("repaint")) })
    for (const g of Object.keys(GROUPS)) bindPicks(this.el, g)
    bindColours(this.el)
    paint()
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
