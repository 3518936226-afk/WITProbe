import fs from 'node:fs';
import path from 'node:path';
// Location is machine-local; versions stay in the committed lock file.
export function resolveToolchain(root, pin) {
  const localFile = path.join(root, 'toolchain.local.json');
  const local = fs.existsSync(localFile) ? JSON.parse(fs.readFileSync(localFile, 'utf8').replace(/^\uFEFF/, '')) : {};
  return process.env.WITPROBE_MOON_HOME || local.toolchain_path || process.env.MOON_HOME || pin.toolchain_path || null;
}
