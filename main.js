import Main from "./src/Main.elm";
import MapboxGL from "mapbox-gl";

const mapboxAccessToken = import.meta.env.VITE_APP_MAPBOX_ACCESS_TOKEN;
let app = Main.init({
  node: document.getElementById("app"),
  flags: {
    mapboxAccessToken,
    mapboxSessionToken: window.crypto.randomUUID(),
  },
});

customElements.define(
  "mapbox-gl",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["coordinates"];
    }
    constructor() {
      super();
      this.map = null;
    }
    connectedCallback() {
      this.map = new MapboxGL.Map({
        container: this,
        style: "mapbox://styles/mapbox/streets-v12",
        center: [0, 0],
        zoom: 2,
        accessToken: mapboxAccessToken,
      });

      this.map.on("load", () => {
        this.dispatchEvent(
          new CustomEvent("ready", {
            bubbles: true,
            composed: true,
          })
        );
      });
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "coordinates") {
        const coordinates = JSON.parse(newValue);
        this.map.flyTo({
          center: [coordinates.longitude, coordinates.latitude],
          zoom: 14,
          essential: true,
        });
      }
    }
  }
);

customElements.define(
  "li-focus-manager",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["has-focus"];
    }
    constructor() {
      super();
    }

    connectedCallback() {
      this.addEventListener("keydown", (e) => {
        if (e.key === "ArrowDown" || e.key === "ArrowUp") {
          e.preventDefault();
        }
      });
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "has-focus") {
        if (newValue == "true") {
          this.firstElementChild.focus();
        } else {
          this.firstElementChild?.blur();
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
        );
      }
    }
  }
);

customElements.define(
  "input-focus-manager",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["has-focus", "cursor-action"];
    }
    constructor() {
      super();
      this.lastSelection = null;
    }

    connectedCallback() {
      this.addEventListener("keydown", (e) => {
        if (e.key === "ArrowDown" || e.key === "ArrowUp") {
          e.preventDefault();
        }
      });
      this.firstElementChild.addEventListener("selectionchange", (e) => {
        const start = this.firstElementChild.selectionStart;
        const end = this.firstElementChild.selectionEnd;
        this.lastSelection = { start, end };
      });
    }

    attributeChangedCallback(name, _, newValue) {
      if (name === "has-focus") {
        window.requestAnimationFrame(() => {
          if (newValue == "true") {
            this.firstElementChild.focus();
          } else {
            this.firstElementChild?.blur();
          }
        });
      }
      if (name === "cursor-action") {
        const start =
          this.lastSelection?.start ?? this.firstElementChild.selectionStart;
        const end =
          this.lastSelection?.end ?? this.firstElementChild.selectionEnd;

        window.requestAnimationFrame(() => {
          if (newValue == "right") {
            this.firstElementChild.setSelectionRange(start + 1, end + 1);
          }
          if (newValue == "left") {
            this.firstElementChild.setSelectionRange(start - 1, end - 1);
          }
          this.dispatchEvent(
            new CustomEvent("reset", {
              bubbles: true,
              composed: true,
            })
          );
        });
      }
    }
  }
);
