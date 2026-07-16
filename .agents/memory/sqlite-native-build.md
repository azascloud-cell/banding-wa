---
name: better-sqlite3 native build
description: better-sqlite3 requires native compilation; pnpm blocks it unless explicitly allowed
---

## Rule
`better-sqlite3` must be listed in `onlyBuiltDependencies` in the root `pnpm-workspace.yaml`, otherwise pnpm skips its `node-gyp` build and the `.node` binding is missing at runtime.

**Why:** pnpm 10+ blocks all native build scripts by default for supply-chain safety. `better-sqlite3` ships a `binding.gyp` that compiles `better_sqlite3.node` — without it, `new Database(path)` throws "Could not locate the bindings file".

**How to apply:**
```yaml
onlyBuiltDependencies:
  - better-sqlite3   # ← add this
  - esbuild
  - ...
```
Then run `pnpm install` from the workspace root — the install output will show `better-sqlite3 install: Done`.
