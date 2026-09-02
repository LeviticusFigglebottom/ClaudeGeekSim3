#!/usr/bin/env node
// Fetch ONLY the Web export templates out of Godot's export-template archive.
//
// The published .tpz for one Godot version is ~1.3 GB because it carries every
// platform; a web export needs two files out of it (~10 MB each). Downloading
// the lot on a hosting provider's build machine is slow and wasteful, so this
// reads the archive's central directory over HTTP range requests and pulls
// down just the entries it needs.
//
//   node tools/fetch_web_templates.mjs [--version 4.7-stable] [--dest DIR]
//                                      [--only web_release.zip,web_debug.zip]
//                                      [--force]
//
// Transport is curl: it is on every machine that can already fetch Godot, and
// it honours HTTPS_PROXY, which Node's fetch does not.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { readEndRecord, readDirectory, dataOffset, decompress } from "./lib/zip.mjs";

const args = process.argv.slice(2);
const option = (name, fallback) => {
	const i = args.indexOf("--" + name);
	return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const VERSION = option("version", process.env.GODOT_VERSION || "4.7-stable");
// "4.7-stable" is the download tag; "4.7.stable" is the directory Godot looks in
const TEMPLATE_VERSION = VERSION.replace("-", ".");
const DEST = option("dest", process.env.GODOT_TEMPLATE_DIR ||
	join(homedir(), ".local", "share", "godot", "export_templates", TEMPLATE_VERSION));
const WANTED = option("only", process.env.GODOT_WEB_TEMPLATES || "web_release.zip,web_nothreads_release.zip")
	.split(",").map((s) => s.trim()).filter(Boolean);
const FORCE = args.includes("--force");
const URL = `https://github.com/godotengine/godot-builds/releases/download/${VERSION}/Godot_v${VERSION}_export_templates.tpz`;

const log = (...m) => console.log("[templates]", ...m);
const range = (from, to) => execFileSync("curl", ["-sfL", "--range", `${from}-${to}`, URL],
	{ maxBuffer: 1 << 30, encoding: "buffer" });

function archiveSize() {
	const head = execFileSync("curl", ["-sfIL", URL], { encoding: "utf8", maxBuffer: 1 << 24 });
	const size = [...head.matchAll(/^content-length:\s*(\d+)/gim)].map((m) => Number(m[1])).filter(Boolean).pop();
	if (!size) {
		throw new Error("could not read Content-Length for " + URL);
	}
	if (!/accept-ranges:\s*bytes/i.test(head)) {
		throw new Error("the server will not serve byte ranges; fetch the .tpz by hand and unzip it into " + DEST);
	}
	return size;
}

mkdirSync(DEST, { recursive: true });
const missing = WANTED.filter((name) => FORCE || !existsSync(join(DEST, name)));
if (missing.length === 0) {
	log(`already in ${DEST}: ${WANTED.join(", ")}`);
	process.exit(0);
}
log(`need ${missing.join(", ")} for Godot ${VERSION}`);

const total = archiveSize();
log(`archive is ${(total / 1e6).toFixed(0)} MB; reading its index rather than the whole thing`);
const tailSize = Math.min(65 * 1024, total);
const tailStart = total - tailSize;
const end = readEndRecord(range(tailStart, total - 1), tailStart);
const entries = readDirectory(range(end.offset, end.offset + end.size - 1), end.entries);
log(`${entries.length} entries in the archive`);

let fetched = 0;
for (const want of missing) {
	const entry = entries.find((e) => e.name === want || e.name.endsWith("/" + want));
	if (!entry) {
		const web = entries.filter((e) => /web/i.test(e.name)).map((e) => e.name).join(", ");
		throw new Error(`'${want}' is not in the archive. Web entries: ${web || "(none)"}`);
	}
	const start = dataOffset(entry, range(entry.offset, entry.offset + 29));
	const data = decompress(entry, range(start, start + entry.compressedSize - 1));
	writeFileSync(join(DEST, want), data);
	fetched += entry.compressedSize;
	log(`${want}: ${(data.length / 1e6).toFixed(1)} MB -> ${join(DEST, want)}`);
}
writeFileSync(join(DEST, "version.txt"), TEMPLATE_VERSION + "\n");
log(`done; downloaded ${(fetched / 1e6).toFixed(0)} MB of ${(total / 1e6).toFixed(0)} MB`);
