import Main from "./src/elm/Main.elm"
import "./src/js/customElements"

const mapboxAccessToken = import.meta.env.VITE_APP_MAPBOX_ACCESS_TOKEN
const mapboxSessionToken =
  window.sessionStorage.getItem("session_id") ?? window.crypto.randomUUID()
window.sessionStorage.setItem("session_id", mapboxSessionToken)

let app = Main.init({
  node: document.getElementById("app"),
  flags: {
    mapboxAccessToken,
    mapboxSessionToken,
  },
})

// Get the user's current position as soon as the app loads, and send it to Elm
window.navigator.geolocation.getCurrentPosition(
  (currentPosition) => {
    app.ports.fromJs.send({
      type: "CurrentPositionSuccess",
      latitude: currentPosition.coords.latitude,
      longitude: currentPosition.coords.longitude,
    })
  },
  (error) => {
    app.ports.fromJs.send({
      type: "CurrentPositionError",
      error: error.message,
    })
  }
)
