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

// --- the rail's width: dragged, nudged with the arrows, reset with a double click, kept
const RAIL_KEY = "wb-console-rail", RAIL_MIN = 300, RAIL_MAX_SHARE = 0.5, RAIL_DEFAULT = 380
export const Rail = {
  mounted() {
    const app = this.el, grip = app.querySelector("#rail-grip")
    const setRail = px => {
      const max = Math.max(RAIL_MIN, Math.round(innerWidth * RAIL_MAX_SHARE))
      const w = Math.round(Math.min(max, Math.max(RAIL_MIN, px)))
      app.style.setProperty("--rail", w + "px")
      grip.setAttribute("aria-valuenow", String(w)); grip.setAttribute("aria-valuemin", String(RAIL_MIN)); grip.setAttribute("aria-valuemax", String(max))
      grip.title = `${w}px — drag, or arrow keys; double-click for ${RAIL_DEFAULT}`
      return w
    }
    const width = () => parseInt(getComputedStyle(app).getPropertyValue("--rail"), 10) || RAIL_DEFAULT
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
    this.resize = () => setRail(width())
    addEventListener("resize", this.resize)
    const saved = store.get(RAIL_KEY)
    setRail(saved ? +saved : RAIL_DEFAULT)
    // The frame the reader chose — the band's side, the rail's — as classes on <body>.
    try { for (const cls of JSON.parse(store.get("wb-console-frame") || "[]")) document.body.classList.add(cls) } catch (e) {}
  },
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
    const badge = document.getElementById("logs-badge"), live = document.getElementById("logs-live")
    const onScreen = () => location.pathname.replace(/\/$/, "").endsWith("/logs")
    const passes = l => !(logs.services[l.service] === false) && rank[l.level] >= rank[logs.level] && (!logs.q || l.text.toLowerCase().includes(logs.q.toLowerCase()))
    const lineEl = l => {
      const m = h("span", "m")
      if (logs.q) { const i = l.text.toLowerCase().indexOf(logs.q.toLowerCase()); if (i >= 0) { m.append(l.text.slice(0, i), Object.assign(h("mark"), { textContent: l.text.slice(i, i + logs.q.length) }), l.text.slice(i + logs.q.length)) } else m.textContent = l.text }
      else m.textContent = l.text
      const n = h("div", "ln " + l.level + (l.cont ? " cont" : "") + (logs.q ? " hit" : ""))
      n.style.setProperty("--svc", svcColor(l.service))
      n.append(h("span", "t", fmtTs(l.ts)), h("span", "s", l.service), m)
      return n
    }
    const renderCount = () => { const vis = logs.all.filter(passes).length; $("#log-count").textContent = `${vis} of ${logs.all.length} lines` + (logs.q ? ` matching “${logs.q}”` : "") }
    const renderBadge = () => { if (badge) { badge.hidden = !logs.unseenErrors; badge.textContent = logs.unseenErrors + " err" } if (live) live.style.display = logs.follow ? "" : "none" }
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
      if (!vis.length) box.append(h("div", "empty", logs.all.length ? "Nothing matches." : "No lines yet."))
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
  mounted() {
    // Every figure gets the expand hint and opens the viewer.
    for (const img of this.el.querySelectorAll("article.md img")) {
      if (img.closest(".fig")) continue
      const wrap = document.createElement("figure"); wrap.className = "fig"
      img.replaceWith(wrap); const hint = document.createElement("span"); hint.className = "expand"; hint.textContent = "⤢ expand"; wrap.append(img, hint)
      wrap.addEventListener("click", () => openViewer(img, img.alt || "Figure"))
    }
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
