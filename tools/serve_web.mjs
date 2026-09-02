#!/usr/bin/env node
// Serve build/web/ the way a host must serve it: with the cross-origin
// isolation headers a threaded Godot build needs (SharedArrayBuffer), and with
// honest content types.
//
//   node tools/serve_web.mjs [--port 8060] [--dir build/web]
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { join, normalize, extname } from "node:path";

const args = process.argv.slice(2);
const option = (name, fallback) => {
	const i = args.indexOf("--" + name);
	return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const PORT = Number(option("port", process.env.PORT || 8060));
const DIR = option("dir", "build/web");

const TYPES = {
	".html": "text/html; charset=utf-8",
	".js": "text/javascript; charset=utf-8",
	".mjs": "text/javascript; charset=utf-8",
	".wasm": "application/wasm",
	".pck": "application/octet-stream",
	".png": "image/png",
	".json": "application/json",
	".svg": "image/svg+xml",
	".ico": "image/x-icon",
};

const server = createServer(async (req, res) => {
	const url = decodeURIComponent((req.url || "/").split("?")[0]);
	const rel = normalize(url === "/" ? "/index.html" : url).replace(/^(\.\.[/\\])+/, "");
	const path = join(DIR, rel);
	try {
		const info = await stat(path);
		if (!info.isFile()) {
			throw new Error("not a file");
		}
		const body = await readFile(path);
		res.writeHead(200, {
			"Content-Type": TYPES[extname(path)] || "application/octet-stream",
			"Content-Length": body.length,
			// what makes SharedArrayBuffer (and so threads) legal on the page
			"Cross-Origin-Opener-Policy": "same-origin",
			"Cross-Origin-Embedder-Policy": "require-corp",
			"Cross-Origin-Resource-Policy": "same-origin",
			"Cache-Control": "no-store",
		});
		res.end(req.method === "HEAD" ? undefined : body);
	} catch {
		res.writeHead(404, { "Content-Type": "text/plain" });
		res.end("not found: " + rel + "\n");
	}
});

server.listen(PORT, () => {
	console.log(`[serve] ${DIR} on http://localhost:${PORT} (cross-origin isolated)`);
});
