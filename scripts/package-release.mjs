import { execFileSync } from "node:child_process";
import {
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { createHash } from "node:crypto";
import { join, relative, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const artifacts = resolve(root, "artifacts");
const packageRoot = resolve(artifacts, "package");
const status = execFileSync("git", ["status", "--porcelain"], {
  cwd: root,
  encoding: "utf8",
}).trim();
if (status && process.env.ALLOW_DIRTY !== "1") {
  throw new Error("Release packaging requires a clean worktree");
}

const required = [
  "pkg/maataa_runtime_bg.wasm",
  "pkg/maataa_runtime.js",
  "apps/siddham-authority-desktop/dist/index.html",
];
for (const path of required) {
  if (!existsSync(resolve(root, path))) throw new Error(`Required build artifact missing: ${path}`);
}

rmSync(artifacts, { recursive: true, force: true });
mkdirSync(packageRoot, { recursive: true });
execFileSync(process.execPath, [resolve(root, "scripts/generate-sbom.mjs")], {
  cwd: root,
  stdio: "inherit",
});

for (const path of [
  "pkg",
  "apps/siddham-authority-desktop/dist",
  "generated",
  "contracts/generated",
  "services/edge_worker/src/generated",
]) {
  cpSync(resolve(root, path), resolve(packageRoot, path), {
    recursive: true,
    filter: (source) => !source.includes("__pycache__") && !source.endsWith(".pyc"),
  });
}

function filesBelow(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = join(directory, entry.name);
    return entry.isDirectory() ? filesBelow(path) : [path];
  });
}
function digest(path) {
  return createHash("sha256").update(readFileSync(path)).digest("hex");
}

const revision = execFileSync("git", ["rev-parse", "HEAD"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const sourceDate = execFileSync("git", ["show", "-s", "--format=%cI", "HEAD"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const packagedFiles = filesBelow(packageRoot)
  .map((path) => ({
    path: relative(artifacts, path).replaceAll("\\", "/"),
    sha256: digest(path),
    bytes: statSync(path).size,
  }))
  .sort((a, b) => a.path.localeCompare(b.path));
const manifest = {
  schemaVersion: 1,
  product: "MAATAA x Siddham engineering artifacts",
  productVersion: "1.0.0-phase1",
  sourceRevision: revision,
  sourceDate,
  contractVersion: "1.0.0",
  dirtyBuildAllowed: process.env.ALLOW_DIRTY === "1",
  productionCertified: false,
  artifacts: packagedFiles,
};
writeFileSync(
  resolve(artifacts, "release-manifest.json"),
  `${JSON.stringify(manifest, null, 2)}\n`,
);

const checksummedFiles = filesBelow(artifacts)
  .filter((path) => !path.endsWith("SHA256SUMS"))
  .sort();
const checksumText = `${checksummedFiles
  .map((path) => `${digest(path)}  ${relative(artifacts, path).replaceAll("\\", "/")}`)
  .join("\n")}\n`;
writeFileSync(resolve(artifacts, "SHA256SUMS"), checksumText);
for (const line of checksumText.trim().split("\n")) {
  const [expected, artifactPath] = line.split("  ");
  const actual = digest(resolve(artifacts, artifactPath));
  if (actual !== expected) throw new Error(`Checksum verification failed: ${artifactPath}`);
}
console.log(`Release package: ${packagedFiles.length} files for ${revision}`);
console.log(`Checksums verified: ${checksummedFiles.length} files -> artifacts/SHA256SUMS`);
