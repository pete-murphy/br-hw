// @ts-check
import { defineConfig } from "astro/config"

import tailwindcss from "@tailwindcss/vite"
import elmstronaut from "elmstronaut"

import cloudflare from "@astrojs/cloudflare"

// https://astro.build/config
export default defineConfig({
  integrations: [elmstronaut()],

  vite: {
    plugins: [tailwindcss()],
  },

  // experimental: {
  //   session: true,
  // },

  // session: {
  //   driver: "sessionStorage",
  // },

  adapter: cloudflare(),
})
