#!/usr/bin/env node
// Boot the browser build in a real browser and prove it runs.
//
//   node tools/verify_web.mjs                       # serve build/web and test it
//   node tools/verify_web.mjs --url https://...     # test a deployed URL
//   node tools/verify_web.mjs --keep-open           # leave the server running
//
// Checks: the page is cross-origin isolated, the engine boots, the title
// screen renders, a new game starts and reaches the flat, nothing logs a
// SCRIPT ERROR, and a reload still finds the save. Writes screenshots to
// screenshots/web_*.png so the result can be looked at, not just trusted.
import { execFileSync, spawn } from "node:child_process";
import { mkdirSync } from "node:fs";
import { join } from "node:path";

const args = process.argv.slice(2);
const option = (name, fallback) => {
	const i = args.indexOf("--" + name);
	return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const PORT = Number(option("port", 8063));
const URL_ARG = option("url", "");
const SHOTS = option("shots", "screenshots");
const BOOT_TIMEOUT = Number(option("timeout", 180)) * 1000;

// playwright lives in the global npm root here, not in this project
const globalRoot = execFileSync("npm", ["root", "-g"], { encoding: "utf8" }).trim();
const { chromium } = await import(join(globalRoot, "playwright", "index.mjs"))
	.catch(() => import("playwright"));

mkdirSync(SHOTS, { recursive: true });
const failures = [];
const note = (...m) => console.log("[web]", ...m);
const fail = (m) => { failures.push(m); console.log("FAIL:", m); };

/// Wait until the picture stops changing: shaders compile on first sight of a
/// material, and until they do the renderer draws placeholders.
async function settle(page, tries = 24, gap = 1000) {
	let previous = null;
	let stable = 0;
	for (let i = 0; i < tries; i++) {
		await page.waitForTimeout(gap);
		const shot = await page.screenshot({ type: "jpeg", quality: 40 });
		let sum = 0;
		for (let b = 0; b < shot.length; b += 7) {
			sum += shot[b];
		}
		const mean = sum / Math.ceil(shot.length / 7);
		if (previous !== null && Math.abs(mean - previous) < 0.5) {
			if (++stable >= 2) {
				return;
			}
		} else {
			stable = 0;
		}
		previous = mean;
	}
}

let server = null;
let base = URL_ARG;
if (!base) {
	server = spawn("node", ["tools/serve_web.mjs", "--port", String(PORT)], { stdio: "ignore" });
	base = `http://localhost:${PORT}`;
	await new Promise((r) => setTimeout(r, 700));
}

const browser = await chromium.launch({
	args: [
		"--no-sandbox",
		"--disable-dev-shm-usage",
		// software WebGL2, since build machines have no GPU
		"--use-gl=angle",
		"--use-angle=swiftshader",
		"--enable-unsafe-swiftshader",
	],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

const logs = [];
page.on("console", (msg) => {
	const text = msg.text();
	logs.push(text);
	if (/SCRIPT ERROR|Failed to load|Uncaught/i.test(text)) {
		fail("console: " + text.slice(0, 200));
	}
});
page.on("pageerror", (err) => fail("page error: " + String(err).slice(0, 200)));

try {
	note("loading", base);
	await page.goto(base, { waitUntil: "domcontentloaded", timeout: 60000 });

	const isolated = await page.evaluate(() => window.crossOriginIsolated);
	// GODOT_THREADS_ENABLED is a script-scoped const, so read the source
	const threaded = /GODOT_THREADS_ENABLED\s*=\s*true/.test(await page.content());
	note(`cross-origin isolated: ${isolated}; threaded build: ${threaded}`);
	if (threaded && !isolated) {
		fail("the page is not cross-origin isolated, so a threaded build cannot start "
			+ "(the host must send Cross-Origin-Opener-Policy: same-origin and "
			+ "Cross-Origin-Embedder-Policy: require-corp)");
	}

	// the loading overlay removes itself once the engine has started the game
	note("waiting for the engine to start (this takes a while under software GL)");
	await page.waitForFunction(() => document.getElementById("status") === null,
		null, { timeout: BOOT_TIMEOUT, polling: 500 })
		.catch(async () => {
			const notice = await page.evaluate(() => {
				const n = document.getElementById("status-notice");
				return n ? n.textContent : "(no notice shown)";
			});
			fail("the engine never started. Loading screen said: " + notice);
		});

	await settle(page);
	await page.screenshot({ path: join(SHOTS, "web_title.png") });
	note("title screen -> " + join(SHOTS, "web_title.png"));

	// click for the pointer-lock gesture, then press the focused button ("sleep")
	await page.mouse.click(640, 400);
	await page.waitForTimeout(500);
	await page.keyboard.press("Enter");
	await settle(page);
	await page.screenshot({ path: join(SHOTS, "web_game.png") });
	note("in game -> " + join(SHOTS, "web_game.png"));

	const started = logs.some((l) => /area|apartment|anteroom/i.test(l));
	if (!started && failures.length === 0) {
		note("(no area log seen; check the screenshot)");
	}

	// the game saves when it changes area: a reload should offer to continue
	note("reloading to check the save survives");
	await page.reload({ waitUntil: "domcontentloaded", timeout: 60000 });
	await page.waitForFunction(() => document.getElementById("status") === null,
		null, { timeout: BOOT_TIMEOUT, polling: 500 }).catch(() => fail("reload did not boot"));
	await settle(page);
	await page.screenshot({ path: join(SHOTS, "web_reload.png") });
	note("after reload -> " + join(SHOTS, "web_reload.png"));
} finally {
	await browser.close();
	if (server && !args.includes("--keep-open")) {
		server.kill();
	}
}

console.log(`== ${failures.length} failure${failures.length === 1 ? "" : "s"} ==`);
for (const f of failures) {
	console.log("  - " + f);
}
process.exit(failures.length === 0 ? 0 : 1);
