import { execFileSync } from "node:child_process";
import { existsSync, lstatSync, readFileSync, readdirSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const excludedDirectories = new Set([
  ".git",
  "node_modules",
  "target",
  "pkg",
  ".wrangler",
  "__pycache__",
  "vendor",
]);
const allowedLargeFiles = new Set(["references/siddham/landing-pages.html"]);
const secretPatterns = [
  /BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY/,
  /AKIA[0-9A-Z]{16}/,
  /gh[pousr]_[A-Za-z0-9_]{20,}/,
  /sk-[A-Za-z0-9_-]{20,}/,
];
const failures = [];
let scannedFiles = 0;

function visit(directory) {
  for (const entry of readdirSync(directory, { withFileTypes: true })) {
    const absolute = join(directory, entry.name);
    const path = relative(root, absolute);
    if (entry.isDirectory()) {
      if (!excludedDirectories.has(entry.name)) visit(absolute);
      continue;
    }
    if (!entry.isFile()) continue;
    scannedFiles += 1;
    const size = lstatSync(absolute).size;
    if (size > 10 * 1024 * 1024 && !allowedLargeFiles.has(path)) {
      failures.push(`Unapproved file above 10 MiB: ${path}`);
    }
    if (size <= 10 * 1024 * 1024) {
      const content = readFileSync(absolute, "utf8");
      if (secretPatterns.some((pattern) => pattern.test(content))) {
        failures.push(`Potential secret pattern in: ${path}`);
      }
    }
  }
}

visit(root);

const tracked = execFileSync("git", ["ls-files"], {
  cwd: root,
  encoding: "utf8",
})
  .trim()
  .split("\n")
  .filter(Boolean);
for (const path of tracked) {
  if (
    /^(?:build|target|pkg|node_modules|\.wrangler)\//.test(path) &&
    existsSync(join(root, path))
  ) {
    failures.push(`Tracked reproducible output: ${path}`);
  }
}

for (const path of ["LICENSE-MIT", "LICENSE-APACHE", "Cargo.lock", "package-lock.json"]) {
  if (!existsSync(join(root, path))) failures.push(`Required baseline file missing: ${path}`);
}

for (const path of ["Cargo.toml", "crates/siddham-contracts/Cargo.toml", "apps/siddham-authority-desktop/src-tauri/Cargo.toml"]) {
  const manifest = readFileSync(join(root, path), "utf8");
  if (!/^license\s*=\s*"MIT OR Apache-2\.0"/m.test(manifest)) {
    failures.push(`Missing canonical licence expression: ${path}`);
  }
}

console.log(`Repository hygiene: scanned ${scannedFiles} files`);
if (failures.length) {
  failures.forEach((failure) => console.error(failure));
  process.exit(1);
}
console.log("Repository hygiene: PASS");
