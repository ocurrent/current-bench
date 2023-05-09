import { defineConfig } from "vite";
import reactRefresh from "@vitejs/plugin-react-refresh";
import env from "vite-plugin-env-compatible";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [reactRefresh(), env({ prefix: "VITE_" })],
  server: {
    port: 8082
  }
});
