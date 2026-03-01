# Polychrome Void

Abstract geometric minimal bullet hell roguelite built with Godot 4.5.

## Play on GitHub Pages

This repository is set up to publish the web export from the `web/` folder.

After enabling GitHub Pages for this repository (Settings -> Pages -> Deploy from a branch -> `main` + `/(root)`), your game URL will be:

- `https://<username>.github.io/<repo>/web/`

## Update and redeploy

1. Export the game for Web from Godot to `web/index.html`.
2. Commit updated files in `web/` (`index.html`, `index.js`, `index.wasm`, `index.pck`, and related assets).
3. Push to `main`.
4. GitHub Pages serves the latest build at `/web/`.
