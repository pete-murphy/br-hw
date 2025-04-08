import MapboxGL from "mapbox-gl"
import "mapbox-gl/dist/mapbox-gl.css"
import StyleObserver, {
  NotificationMode,
  ReturnFormat,
} from "@bramus/style-observer"

const LIGHT_STYLE = "mapbox://styles/pfmurphy/cm95zdls0003g01qh1p3da2ym"
const DARK_STYLE = "mapbox://styles/pfmurphy/cm96j9rx900ag01qt2uwseypm"
const COLOR_SCHEME = "--color-scheme"

const prefersColorSchemeDark = window.matchMedia("(prefers-color-scheme: dark)")

function getColorScheme(
  colorScheme = document.documentElement.style.getPropertyValue(COLOR_SCHEME)
) {
  const systemPreference = prefersColorSchemeDark.matches ? "dark" : "light"
  if (colorScheme === "light dark" || colorScheme === "") {
    return systemPreference
  }
  return colorScheme
}

// Mapbox GL custom element
customElements.define(
  "mapbox-gl",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["center", "markers", "highlighted-marker", "access-token"]
    }
    constructor() {
      super()
      this.map = null
      this.markers = new Map()
      this.moveendTimeout = null
      this.styleObserver = null
    }

    connectedCallback() {
      const colorScheme = getColorScheme()
      this.map = new MapboxGL.Map({
        container: this,
        style: colorScheme === "dark" ? DARK_STYLE : LIGHT_STYLE,
        center: [0, 0],
        zoom: 2,
        accessToken: this.getAttribute("access-token"),
        maxZoom: 16,
        minZoom: 2,
        cooperativeGestures: true,
      }).setPadding({
        top: 10,
        right: 10,
        bottom: 10,
        left: 10,
      })

      // Listen for changes to prefers-color-scheme
      prefersColorSchemeDark.addEventListener("change", (colorScheme) => {
        const newColorScheme = getColorScheme(colorScheme)
        this.map.setStyle(newColorScheme === "dark" ? DARK_STYLE : LIGHT_STYLE)
      })

      this.styleObserver = new StyleObserver(
        () => {
          const newColorScheme = getColorScheme()
          this.map.setStyle(
            newColorScheme === "dark" ? DARK_STYLE : LIGHT_STYLE
          )
        },
        {
          // TODO: using `--color-scheme` in here doesn't work?
          properties: ["color-scheme"],
          notificationMode: NotificationMode.IMMEDIATE,
          returnFormat: ReturnFormat.STRING,
        }
      )
      this.styleObserver.observe(document.documentElement)

      this.map.on("load", () => {
        this.dispatchEvent(
          new CustomEvent("load", {
            bubbles: true,
            composed: true,
            detail: {
              center: this.map.getCenter().toArray(),
              bounds: this.map.getBounds().toArray(),
            },
          })
        )
      })

      this.map.on("movestart", () => {
        if (this.moveendTimeout) {
          clearTimeout(this.moveendTimeout)
        }
      })

      this.map.on("moveend", () => {
        if (this.moveendTimeout) {
          clearTimeout(this.moveendTimeout)
        }
        this.moveendTimeout = setTimeout(() => {
          this.dispatchEvent(
            new CustomEvent("moveend", {
              bubbles: true,
              composed: true,
              detail: {
                center: this.map.getCenter().toArray(),
                bounds: this.map.getBounds().toArray(),
              },
            })
          )
        }, 300)
      })
    }

    disconnectedCallback() {
      this.styleObserver?.disconnect()
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "center") {
        const center = JSON.parse(newValue)
        if (center.latitude != null && center.longitude != null) {
          this.map?.jumpTo({
            center: [center.longitude, center.latitude],
            zoom: 8,
          })
        }
      }

      if (name === "markers") {
        const markers = JSON.parse(newValue)
        const markersToAdd = markers.filter(
          (marker) => !this.markers.has(marker.id)
        )
        const markerIdsToRemove = new Set(this.markers.keys()).difference(
          new Set(markers.map((marker) => marker.id))
        )

        // Remove markers that are no longer in the list
        for (const markerId of markerIdsToRemove) {
          const marker = this.markers.get(markerId)
          if (marker) {
            marker.remove()
            this.markers.delete(markerId)
          }
        }

        // Add new markers
        for (const marker of markersToAdd) {
          const el = document.createElement("div")
          el.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
  <path fill-rule="evenodd" d="m11.54 22.351.07.04.028.016a.76.76 0 0 0 .723 0l.028-.015.071-.041a16.975 16.975 0 0 0 1.144-.742 19.58 19.58 0 0 0 2.683-2.282c1.944-1.99 3.963-4.98 3.963-8.827a8.25 8.25 0 0 0-16.5 0c0 3.846 2.02 6.837 3.963 8.827a19.58 19.58 0 0 0 2.682 2.282 16.975 16.975 0 0 0 1.145.742ZM12 13.5a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z" clip-rule="evenodd" />
</svg>`
          el.style.width = `2rem`
          el.style.height = `2rem`
          el.style.strokeWidth = `0.5px`
          el.style.stroke = `var(--stroke-color)`
          el.style.strokeOpacity = `0.5`
          el.dataset.id = marker.id
          el.onmouseenter = () => {
            this.dispatchEvent(
              new CustomEvent("marker-mouseenter", {
                bubbles: true,
                composed: true,
                detail: {
                  id: marker.id,
                },
              })
            )
          }
          el.onmouseleave = () => {
            this.dispatchEvent(
              new CustomEvent("marker-mouseleave", {
                bubbles: true,
                composed: true,
                detail: {
                  id: marker.id,
                },
              })
            )
          }

          const mapboxMarker = new MapboxGL.Marker({
            element: el,
            anchor: "bottom",
          })
            .setLngLat([marker.longitude, marker.latitude])
            .addTo(this.map)
          this.markers.set(marker.id, mapboxMarker)
        }
      }

      if (name === "highlighted-marker") {
        const highlightedMarkerId = JSON.parse(newValue)
        if (!highlightedMarkerId) {
          this.markers.forEach((marker) => {
            marker.getElement().dataset.highlighted = "none"
          })
        } else {
          this.markers.forEach((marker, id) => {
            if (id === highlightedMarkerId) {
              marker.getElement().dataset.highlighted = "true"
            } else {
              marker.getElement().dataset.highlighted = "false"
            }
          })
        }
      }
    }
  }
)

// Custom element for managing focus of list item in the combobox listbox
customElements.define(
  "li-focus-manager",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["has-focus"]
    }
    constructor() {
      super()
    }

    connectedCallback() {
      this.addEventListener("keydown", (e) => {
        if (e.key === "ArrowDown" || e.key === "ArrowUp") {
          e.preventDefault()
        }
      })
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "has-focus") {
        if (newValue == "true") {
          this.firstElementChild?.focus()
        }
      }
    }

    disconnectedCallback() {
      if (this.getAttribute("has-focus") == "true") {
        this.dispatchEvent(
          new CustomEvent("remove", {
            bubbles: true,
            composed: true,
          })
        )
      }
    }
  }
)

// Custom element for managing focus of combobox input
customElements.define(
  "input-focus-manager",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["has-focus", "cursor-action"]
    }
    constructor() {
      super()
      this.lastSelection = null
    }

    connectedCallback() {
      this.addEventListener("keydown", (e) => {
        if (e.key === "ArrowDown" || e.key === "ArrowUp") {
          e.preventDefault()
        }
      })
      this.firstElementChild?.addEventListener("selectionchange", (e) => {
        const start = this.firstElementChild?.selectionStart
        const end = this.firstElementChild?.selectionEnd
        if (start == null || end == null) {
          return
        }
        this.lastSelection = { start, end }
      })
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "has-focus") {
        window.requestAnimationFrame(() => {
          if (newValue == "true") {
            this.firstElementChild?.focus()
          }
        })
      }
      if (name === "cursor-action") {
        const start =
          this.lastSelection?.start ?? this.firstElementChild?.selectionStart
        const end =
          this.lastSelection?.end ?? this.firstElementChild?.selectionEnd

        window.requestAnimationFrame(() => {
          if (newValue == "right") {
            this.firstElementChild.setSelectionRange(start + 1, end + 1)
          }
          if (newValue == "left") {
            this.firstElementChild.setSelectionRange(start - 1, end - 1)
          }
          this.dispatchEvent(
            new CustomEvent("reset", {
              bubbles: true,
              composed: true,
            })
          )
        })
      }
    }
  }
)

// A custom element for pretty-printing distance as km
customElements.define(
  "distance-formatter",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["distance"]
    }
    constructor() {
      super()
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "distance") {
        const distance = parseFloat(newValue)
        const formatter = new Intl.NumberFormat(undefined, {
          style: "unit",
          unit: "kilometer",
          unitDisplay: "short",
          maximumFractionDigits: 1,
        })
        this.innerText = formatter.format(distance)
      }
    }
  }
)

// Custom element for scrolling item into view
customElements.define(
  "scroll-into-view",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["scroll"]
    }
    constructor() {
      super()
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "scroll") {
        if (newValue == "true") {
          this.scrollIntoView({
            block: "nearest",
            inline: "nearest",
            behavior: window.matchMedia(
              "(prefers-reduced-motion: no-preference)"
            )
              ? "smooth"
              : "auto",
          })
        }
      }
    }
  }
)
