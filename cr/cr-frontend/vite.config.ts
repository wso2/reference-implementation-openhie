import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: process.env.CR_CORE_URL ?? 'http://localhost:9090',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
      '/audit-api': {
        target: process.env.AUDIT_SERVICE_URL ?? 'http://localhost:9096',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/audit-api/, ''),
      },
    },
  },
})
