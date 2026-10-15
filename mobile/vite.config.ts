import { defineConfig } from "vite";
import { fileURLToPath } from "node:url";
export default defineConfig({
  resolve: {
    alias: {
      "@hotwired/stimulus": fileURLToPath(
        new URL(
          "./node_modules/@hotwired/stimulus/dist/stimulus.js",
          import.meta.url,
        ),
      ),
    },
  },
  server: {
    port: 5178,
    strictPort: true,
    proxy: { "/api": "http://127.0.0.1:3000" },
  },
  build: { target: "es2022" },
});
