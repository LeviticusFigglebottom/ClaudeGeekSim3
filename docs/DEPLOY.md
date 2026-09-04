# Putting ANTEROOM on the web

The game ships to a browser as a Godot **Web export**: WebAssembly plus a
resource pack, served as static files. Nothing about the game changes — the
same project, the same 18 areas, the same GL Compatibility renderer that the
desktop build uses (it becomes WebGL 2 in a browser) and the same
`tools/verify.sh` gate, which the build runs before it will produce output.

```
tools/export_web.sh      # verify, then build build/web/  (~43 MB)
tools/serve_web.sh       # preview on http://localhost:8060
node tools/verify_web.mjs # boot it in a real browser and screenshot it
```

## Vercel

The repository is already configured; `vercel.json` carries all of it.

1. **Import the repository** on Vercel (New Project → import → Deploy).
   Framework preset: *Other*. Everything else comes from `vercel.json`:
   build command `bash tools/vercel_build.sh`, output directory `build/web`,
   and no install step (there is no package manager in this project).
2. **First build takes about three to four minutes.** The build machine has no
   Godot, so the script fetches the engine (~50 MB) and *only the web export
   templates* out of Godot's 1.3 GB template archive — `tools/fetch_web_templates.mjs`
   reads the archive's index over HTTP range requests and pulls the ~10 MB it
   needs. Then it imports the assets, runs the world-graph verification, and
   exports.
3. **Check the deployment** with the same browser test that runs in CI:
   ```
   node tools/verify_web.mjs --url https://<your-deployment>.vercel.app
   ```

Nothing needs to be set in the Vercel dashboard. Useful environment variables,
if you ever want them:

| variable | effect |
|---|---|
| `SKIP_VERIFY=1` | skip the world-graph check before exporting (faster, riskier) |
| `GODOT_WEB_THREADS=0` | build the single-threaded variant (see below) |
| `GODOT_VERSION` | engine version to fetch, default `4.7-stable` |
| `USE_PREBUILT_WEB=1` | deploy a `build/web` committed to the repository instead of building |

### The headers matter

The default build uses threads, which means the page needs `SharedArrayBuffer`,
which browsers only hand to a **cross-origin isolated** page. `vercel.json`
sends what that requires:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
Cross-Origin-Resource-Policy: same-origin
```

Without them the game will not start, and the loading screen says so in as many
words. `tools/serve_web.mjs` sends the same headers locally, and `web/_headers`
carries them for Netlify or Cloudflare Pages, so the same build works there too.

If you ever need to host somewhere that cannot set headers, build the
single-threaded variant instead — it runs anywhere, a good deal slower:

```
GODOT_WEB_THREADS=0 tools/export_web.sh
```

### Caching

Vercel's default for static files (`public, max-age=0, must-revalidate` with an
ETag) is deliberately left alone. The engine and the resource pack are served
from fixed paths — `index.wasm`, `index.pck` — so marking them immutable would
hand returning players a new engine with an old pack after a redeploy. As it is,
a repeat visit costs one conditional request per file and everything else comes
from the browser cache.

## What the build produces

| file | size | what it is |
|---|---|---|
| `index.html` | 6 KB | the loading screen (`web/shell.html`, styled like the game) |
| `index.js` | 307 KB | the engine's JavaScript glue |
| `index.wasm` | 38 MB | the engine |
| `index.pck` | 5.7 MB | the whole game: 18 areas, 203 textures, 243 models, 88 sounds |
| `index.audio*.worklet.js` | 10 KB | audio worklets |
| `index*.png` | 22 KB | icons |

## Notes for players in a browser

* **Mouse look** needs a click first: browsers only grant pointer lock after a
  gesture. Clicking *sleep* on the title screen is enough.
* **Saves** (all three slots, and the settings file) live in the browser's
  IndexedDB, per origin. They survive a reload (the browser test checks exactly
  that) but they are not the same saves as the desktop build's, and clearing
  site data clears them.
* **Fullscreen** works from the settings toggle or F11 — browsers only allow
  it from a click or key press, so the saved preference is not applied on load.
* **There is no quit button** in a browser; the title screen leaves it out.
* **F12** belongs to the browser, so the in-game screenshot key does nothing
  there. Everything else is as documented in the README.
* The first seconds after loading draw placeholder materials while shaders
  compile. The loading screen stays up until the engine reports it has drawn a
  real frame, so this is not visible — it is why `web/shell.html` waits for
  `window.anteroomReady()`.
