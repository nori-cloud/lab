import { defineConfig } from "tsup"

export default defineConfig({
  entry: ["src/index.ts"],
  outDir: "dist",
  format: "cjs",
  target: "node22",
  minify: true,
  clean: true
})