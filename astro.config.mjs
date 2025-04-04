// @ts-check
import { defineConfig } from "astro/config"

import tailwindcss from "@tailwindcss/vite"
import elmstronaut from "elmstronaut"

// https://astro.build/config
export default defineConfig({
  integrations: [elmstronaut()],
  vite: {
    plugins: [tailwindcss()],
  },
})
