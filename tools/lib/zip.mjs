// A small read-only ZIP reader.
//
// It exists so the web-export toolchain can pull single files out of Godot's
// distribution archives without a dependency, and — more usefully — without
// downloading the whole archive: `readDirectory` only needs the last few
// kilobytes plus the central directory, so an entry can be fetched by byte
// range out of a 1.3 GB file.
import { inflateRawSync } from "node:zlib";

export const EOCD_SIGNATURE = 0x06054b50;
export const ZIP64_LOCATOR_SIGNATURE = 0x07064b50;
export const CENTRAL_SIGNATURE = 0x02014b50;
export const LOCAL_SIGNATURE = 0x04034b50;

/// Locate the end-of-central-directory record inside the archive's tail.
/// `tail` is the last `tail.length` bytes of the file, starting at `tailStart`.
export function readEndRecord(tail, tailStart) {
	for (let i = tail.length - 22; i >= 0; i--) {
		if (tail.readUInt32LE(i) !== EOCD_SIGNATURE) {
			continue;
		}
		let entries = tail.readUInt16LE(i + 10);
		let size = tail.readUInt32LE(i + 12);
		let offset = tail.readUInt32LE(i + 16);
		if (offset === 0xffffffff || entries === 0xffff) {
			// ZIP64: the real numbers live in a record the locator points at
			for (let j = i - 20; j >= 0; j--) {
				if (tail.readUInt32LE(j) !== ZIP64_LOCATOR_SIGNATURE) {
					continue;
				}
				const at = Number(tail.readBigUInt64LE(j + 8));
				if (at < tailStart) {
					throw new Error("ZIP64 end record lies outside the fetched tail");
				}
				const rec = tail.subarray(at - tailStart);
				entries = Number(rec.readBigUInt64LE(32));
				size = Number(rec.readBigUInt64LE(40));
				offset = Number(rec.readBigUInt64LE(48));
				break;
			}
		}
		return { entries, size, offset };
	}
	throw new Error("no end-of-central-directory record found");
}

/// Parse a central directory into entry descriptors.
export function readDirectory(central, count) {
	const out = [];
	let p = 0;
	for (let n = 0; n < count && p + 46 <= central.length; n++) {
		if (central.readUInt32LE(p) !== CENTRAL_SIGNATURE) {
			break;
		}
		const method = central.readUInt16LE(p + 10);
		const nameLength = central.readUInt16LE(p + 28);
		const extraLength = central.readUInt16LE(p + 30);
		const commentLength = central.readUInt16LE(p + 32);
		const externalAttributes = central.readUInt32LE(p + 38);
		let compressedSize = central.readUInt32LE(p + 20);
		let size = central.readUInt32LE(p + 24);
		let offset = central.readUInt32LE(p + 42);
		const name = central.toString("utf8", p + 46, p + 46 + nameLength);
		if (compressedSize === 0xffffffff || size === 0xffffffff || offset === 0xffffffff) {
			const extra = central.subarray(p + 46 + nameLength, p + 46 + nameLength + extraLength);
			let q = 0;
			while (q + 4 <= extra.length) {
				const id = extra.readUInt16LE(q);
				const length = extra.readUInt16LE(q + 2);
				if (id === 0x0001) {
					let r = q + 4;
					if (size === 0xffffffff) { size = Number(extra.readBigUInt64LE(r)); r += 8; }
					if (compressedSize === 0xffffffff) { compressedSize = Number(extra.readBigUInt64LE(r)); r += 8; }
					if (offset === 0xffffffff) { offset = Number(extra.readBigUInt64LE(r)); r += 8; }
				}
				q += 4 + length;
			}
		}
		// the executable bit, so an extracted Godot binary stays runnable
		const mode = (externalAttributes >>> 16) & 0xfff;
		out.push({ name, method, compressedSize, size, offset, mode });
		p += 46 + nameLength + extraLength + commentLength;
	}
	return out;
}

/// Where an entry's compressed bytes begin, given its 30-byte local header.
export function dataOffset(entry, localHeader) {
	if (localHeader.readUInt32LE(0) !== LOCAL_SIGNATURE) {
		throw new Error("bad local header for " + entry.name);
	}
	return entry.offset + 30 + localHeader.readUInt16LE(26) + localHeader.readUInt16LE(28);
}

/// Decompress an entry's bytes (stored or deflated).
export function decompress(entry, raw) {
	const data = entry.method === 0 ? raw : inflateRawSync(raw);
	if (entry.size && data.length !== entry.size) {
		throw new Error(`${entry.name}: expected ${entry.size} bytes, got ${data.length}`);
	}
	return data;
}
