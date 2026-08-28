import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const metadata = JSON.parse(
  execFileSync("cargo", ["metadata", "--format-version", "1", "--locked"], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  }),
);
const rustMissing = metadata.packages
  .filter((item) => !item.license && !item.license_file)
  .map((item) => `${item.name}@${item.version}`)
  .sort();

const npmLocks = [
  "package-lock.json",
  "apps/siddham-authority-desktop/package-lock.json",
];
const npmMissing = [];
let npmPackages = 0;
for (const path of npmLocks) {
  const lock = JSON.parse(readFileSync(resolve(root, path), "utf8"));
  for (const [packagePath, item] of Object.entries(lock.packages ?? {})) {
    if (!packagePath || packagePath === "node_modules/.package-lock.json") continue;
    npmPackages += 1;
    if (!item.license) npmMissing.push(`${path}:${packagePath}`);
  }
}

console.log(
  `Dependency licence scan: ${metadata.packages.length} Rust packages, ${npmPackages} npm package records`,
);
if (rustMissing.length || npmMissing.length) {
  if (rustMissing.length) {
    console.error(`Rust packages without declared licence metadata: ${rustMissing.join(", ")}`);
  }
  if (npmMissing.length) {
    console.error(`npm records without declared licence metadata: ${npmMissing.join(", ")}`);
  }
  process.exit(1);
}
console.log("Dependency licence metadata: PASS");
