#!/usr/bin/env node
// Decode a .mox to plain .mo for debugging.  Mirrors mox_format.h.
const fs = require('fs');
if (process.argv.length !== 4) {
    console.error('usage: decode_mox.js <input.mox> <output.mo>');
    process.exit(1);
}
const SEED = 0xA17C9E3B4D5F2B89n;

function step(state) {
    let x = state;
    x ^= (x << 13n) & 0xffffffffffffffffn;
    x ^= (x >> 7n);
    x ^= (x << 17n) & 0xffffffffffffffffn;
    return x;
}

const buf = fs.readFileSync(process.argv[2]);
if (buf.toString('ascii', 0, 4) !== 'MOX1') {
    console.error('bad magic');
    process.exit(1);
}
const version = buf.readUInt32LE(4);
const payloadLen = buf.readUInt32LE(8);
const nonce = buf.slice(12, 20);
const payload = Buffer.from(buf.slice(20));
if (payload.length !== payloadLen) {
    console.error('payload length mismatch:', payload.length, payloadLen);
    process.exit(1);
}
let state = SEED;
for (let i = 0; i < 8; i++) {
    state ^= BigInt(nonce[i]) << BigInt(i * 8);
}
if (state === 0n) state = 1n;
let k = 0n;
const keybytes = new Uint8Array(8);
for (let i = 0; i < payload.length; i++) {
    if ((i & 7) === 0) {
        state = step(state);
        k = state;
        for (let j = 0; j < 8; j++) {
            keybytes[j] = Number((k >> BigInt(j * 8)) & 0xffn);
        }
    }
    payload[i] ^= keybytes[i & 7];
}
fs.writeFileSync(process.argv[3], payload);
console.error(`wrote ${payload.length} bytes to ${process.argv[3]}`);
