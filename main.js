import Main from "./src/Main.elm";

let app = Main.init({
  node: document.getElementById("app"),
  flags: {
    mapboxAccessToken: import.meta.env.VITE_APP_MAPBOX_ACCESS_TOKEN,
    mapboxSessionToken: window.crypto.randomUUID(),
  },
});

customElements.define(
  "li-focus-manager",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["has-focus"];
    }
    constructor() {
      super();
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
