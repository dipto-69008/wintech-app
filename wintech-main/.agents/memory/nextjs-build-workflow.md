---
name: Next.js build workflow
description: Replit-specific guidance for avoiding Next.js cache races during verification.
---

When verifying this Next.js app, stop the running dev workflow before running `npm run build`, then restart the workflow after the build completes.

**Why:** The dev server and production build both read and write the shared `.next` directory. Running them concurrently can create transient missing-page or missing-required-files errors even when the source code is valid.

**How to apply:** Use the workflow stop action, remove `.next` only when the cache is inconsistent, run the build serially, and restart the application workflow afterward.