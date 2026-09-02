#!/usr/bin/env node
// Extract a local zip without depending on the `unzip` binary (build machines
// do not all have one).
//
//   node tools/unzip.mjs archive.zip dest/ [entry-substring]
import { readFileSync, mkdirSync, writeFileSync, chmodSync } from "node:fs";
import { dirname, join } from "node:path";
import { readEndRecord, readDirectory, dataOffset, decompress } from "./lib/zip.mjs";

const [archive, dest, filter] = process.argv.slice(2);
if (!archive || !dest) {
	console.error("usage: node tools/unzip.mjs <archive.zip> <dest dir> [entry substring]");
	process.exit(2);
}
const buf = readFileSync(archive);
const end = readEndRecord(buf.subarray(Math.max(0, buf.length - 66560)), Math.max(0, buf.length - 66560));
const entries = readDirectory(buf.subarray(end.offset, end.offset + end.size), end.entries);
let written = 0;
for (const entry of entries) {
	if (entry.name.endsWith("/")) {
		continue;
	}
	if (filter && !entry.name.includes(filter)) {
		continue;
	}
	const start = dataOffset(entry, buf.subarray(entry.offset, entry.offset + 30));
	const data = decompress(entry, buf.subarray(start, start + entry.compressedSize));
	const out = join(dest, entry.name);
	mkdirSync(dirname(out), { recursive: true });
	writeFileSync(out, data);
	if (entry.mode & 0o111) {
		chmodSync(out, 0o755);
	}
	console.log(`[unzip] ${entry.name} (${(data.length / 1e6).toFixed(1)} MB)`);
	written++;
}
if (written === 0) {
	console.error(`[unzip] nothing matched${filter ? " '" + filter + "'" : ""} in ${archive}`);
	process.exit(1);
}
