import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const output = resolve(root, "artifacts/sbom.cdx.json");
const cargo = JSON.parse(
  execFileSync("cargo", ["metadata", "--format-version", "1", "--locked"], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  }),
);

const components = new Map();
for (const item of cargo.packages) {
  const purl = `pkg:cargo/${encodeURIComponent(item.name)}@${item.version}`;
  components.set(purl, {
    type: "library",
    "bom-ref": purl,
    name: item.name,
    version: item.version,
    purl,
    licenses: item.license ? [{ expression: item.license }] : undefined,
  });
}

for (const lockPath of [
  "package-lock.json",
  "apps/siddham-authority-desktop/package-lock.json",
]) {
  const lock = JSON.parse(readFileSync(resolve(root, lockPath), "utf8"));
  for (const [path, item] of Object.entries(lock.packages ?? {})) {
    if (!path || !item.version) continue;
    const name = path.slice(path.lastIndexOf("node_modules/") + 13);
    const purl = `pkg:npm/${encodeURIComponent(name)}@${item.version}`;
    components.set(purl, {
      type: "library",
      "bom-ref": purl,
      name,
      version: item.version,
      purl,
      licenses: item.license ? [{ expression: item.license }] : undefined,
    });
  }
}

const revision = execFileSync("git", ["rev-parse", "HEAD"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const timestamp = execFileSync("git", ["show", "-s", "--format=%cI", "HEAD"], {
  cwd: root,
  encoding: "utf8",
}).trim();
const sbom = {
  bomFormat: "CycloneDX",
  specVersion: "1.6",
  serialNumber: `urn:uuid:${revision.slice(0, 8)}-${revision.slice(8, 12)}-4${revision.slice(13, 16)}-8${revision.slice(17, 20)}-${revision.slice(20, 32)}`,
  version: 1,
  metadata: {
    timestamp,
    component: {
      type: "application",
      name: "allb.xyz",
      version: "1.0.0",
      properties: [{ name: "git:revision", value: revision }],
    },
  },
  components: [...components.values()].sort((a, b) => a.purl.localeCompare(b.purl)),
};

mkdirSync(resolve(root, "artifacts"), { recursive: true });
writeFileSync(output, `${JSON.stringify(sbom, null, 2)}\n`);
console.log(`CycloneDX SBOM: ${sbom.components.length} components -> artifacts/sbom.cdx.json`);
