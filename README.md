# Polychrome Void

Abstract geometric minimal bullet hell roguelite built with Godot 4.5.

## Play on GitHub Pages

This repository is set up with:

- A public homepage at the repository root (`/`)
- The playable web build served from `web/`

After enabling GitHub Pages for this repository (Settings -> Pages -> Deploy from a branch -> `main` + `/(root)`), your URLs will be:

- Homepage: `https://<username>.github.io/<repo>/`
- Playable game: `https://<username>.github.io/<repo>/web/`

## Update and redeploy

1. Export the game for Web from Godot to `web/index.html`.
2. Commit updated files in `web/` (`index.html`, `index.js`, `index.wasm`, `index.pck`, and related assets).
3. Commit homepage updates at the repository root when needed (`index.html`, `styles.css`).
4. Push to `main`.
5. GitHub Pages serves the homepage at `/` and the latest playable build at `/web/`.
