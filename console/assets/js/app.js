// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/console"
import {Booklet, Cli, Clock, Face, Folds, Frame, Ground, JobLines, JobOut, Logs, Rail, ShelfView, Term} from "./hooks"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, Booklet, Cli, Clock, Face, Folds, Frame, Ground, JobLines, JobOut, Logs, Rail, ShelfView, Term},
})

// The band's gold rule is the loading bar. It is always there — a full
// rule is a page with nothing on its way — and a load rewinds it to a
// sliver and lets it creep back, so the only thing ever seen is an
// incomplete one. On :root, which is outside anything LiveView patches.
//
// Nothing that finishes inside 300ms is worth showing, which is the
// delay topbar took too; and the rule completes when the last load
// stops, not the first, so an overlapping pair cannot fill it early.
const rule = (to, speed) => {
  document.documentElement.style.setProperty("--load", String(to))
  document.documentElement.style.setProperty("--load-in", speed)
}
let loading = 0, creep = null
window.addEventListener("phx:page-loading-start", () => {
  if (loading++ > 0) return
  creep = setTimeout(() => {
    // Rewound, then let go. The read in between is what makes it two
    // moves and not one: without a style recalculation forced between
    // the writes the browser only ever sees the last value, and the rule
    // slid from full to nine tenths over eight seconds instead of
    // starting over.
    rule(0.08, "0s")
    getComputedStyle(document.querySelector("header.band")).transform
    rule(0.9, "8s")
  }, 300)
})
window.addEventListener("phx:page-loading-stop", () => {
  if (--loading > 0) return
  loading = 0
  clearTimeout(creep)
  rule(1, ".18s")
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

