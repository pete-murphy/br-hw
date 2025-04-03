import Main from "./src/Main.elm";

let app = Main.init({
  node: document.getElementById("app"),
});

customElements.define(
  "focus-within",
  class extends HTMLElement {
    static get observedAttributes() {
      return ["hasfocus"];
    }
    constructor() {
      super();
      console.log("FocusWithin constructor");
    }

    connectedCallback() {
      console.log("FocusWithin connectedCallback");
    }

    attributeChangedCallback(name, oldValue, newValue) {
      console.log(
        `FocusWithin attributeChangedCallback: ${name} changed from ${oldValue} to ${newValue}`
      );

      if (name === "hasfocus") {
        if (newValue == "true") {
          this.firstElementChild.focus();
        } else {
          this.firstElementChild.blur();
        }
      }
    }

    disconnectedCallback() {
      if (this.getAttribute("hasfocus") == "true") {
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
