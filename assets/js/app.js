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
import topbar from "../vendor/topbar"
import {DarkMode} from "./dark_mode"

// Theme selector hook for settings page
const ThemeSelector = {
  mounted() {
    // Send current theme to LiveView on mount
    const currentTheme = localStorage.getItem("theme") || "system"
    this.pushEvent("init-theme", {theme: currentTheme})
    
    this.handleEvent("set-theme", ({theme}) => {
      if (theme === "system") {
        localStorage.removeItem("theme")
        document.documentElement.classList.remove("dark")
        
        // Apply system preference
        if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) {
          document.documentElement.classList.add("dark")
        }
      } else if (theme === "dark") {
        localStorage.setItem("theme", "dark")
        document.documentElement.classList.add("dark")
      } else {
        localStorage.setItem("theme", "light")
        document.documentElement.classList.remove("dark")
      }
    })
  }
}

// Clipboard hook for copying API keys
const CopyButton = {
  mounted() {
    this.el.addEventListener("click", () => {
      const text = this.el.dataset.clipboardText
      if (!text) return
      
      // Save original button content
      const originalContent = this.el.innerHTML
      
      // Try modern clipboard API first
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(() => {
          this.showSuccess(originalContent)
        }).catch(err => {
          console.error("Failed to copy with clipboard API:", err)
          this.fallbackCopy(text, originalContent)
        })
      } else {
        // Use fallback for older browsers or non-secure contexts
        this.fallbackCopy(text, originalContent)
      }
    })
  },
  
  showSuccess(originalContent) {
    // Change button text to "Copied!"
    this.el.innerHTML = `
      <svg class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
      </svg>
      Copied!
    `
    this.el.classList.add("bg-green-50", "dark:bg-green-900/30", "text-green-700", "dark:text-green-400", "border-green-300", "dark:border-green-700")
    
    // Reset after 2 seconds
    setTimeout(() => {
      this.el.innerHTML = originalContent
      this.el.classList.remove("bg-green-50", "dark:bg-green-900/30", "text-green-700", "dark:text-green-400", "border-green-300", "dark:border-green-700")
    }, 2000)
  },
  
  fallbackCopy(text, originalContent) {
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.style.position = "fixed"
    textarea.style.top = "-999px"
    textarea.style.opacity = "0"
    document.body.appendChild(textarea)
    textarea.focus()
    textarea.select()
    
    try {
      document.execCommand("copy")
      this.showSuccess(originalContent)
    } catch (err) {
      console.error("Fallback copy failed:", err)
    } finally {
      document.body.removeChild(textarea)
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {DarkMode, ThemeSelector, CopyButton},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

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
    window.addEventListener("keyup", e => keyDown = null)
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

