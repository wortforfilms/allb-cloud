import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import Ajv2020 from "ajv/dist/2020.js";
import YAML from "yaml";

const root = resolve(import.meta.dirname, "..");
const jsonFiles = [
  "package.json",
  "package-lock.json",
  "tsconfig.json",
  "wrangler.jsonc",
  "contracts/ecosystem-contract.json",
  "contracts/generated/operation-request.schema.json",
  "contracts/fixtures/valid-runtime-execute.json",
  "contracts/fixtures/invalid-unknown-action.json",
  "apps/siddham-authority-desktop/package.json",
  "apps/siddham-authority-desktop/package-lock.json",
  "apps/siddham-authority-desktop/tsconfig.json",
  "apps/siddham-authority-desktop/src-tauri/tauri.conf.json",
  "apps/siddham-authority-desktop/src-tauri/capabilities/default.json",
];

function parseJsonc(text) {
  return JSON.parse(text.replace(/^\s*\/\/.*$/gm, ""));
}

for (const path of jsonFiles) {
  const text = readFileSync(resolve(root, path), "utf8");
  path.endsWith(".jsonc") ? parseJsonc(text) : JSON.parse(text);
}
YAML.parse(readFileSync(resolve(root, ".github/workflows/ci.yml"), "utf8"));

const schema = JSON.parse(
  readFileSync(resolve(root, "contracts/generated/operation-request.schema.json"), "utf8"),
);
const validFixture = JSON.parse(
  readFileSync(resolve(root, "contracts/fixtures/valid-runtime-execute.json"), "utf8"),
);
const invalidFixture = JSON.parse(
  readFileSync(resolve(root, "contracts/fixtures/invalid-unknown-action.json"), "utf8"),
);
const validate = new Ajv2020({ allErrors: true, strict: true }).compile(schema);
if (!validate(validFixture)) {
  throw new Error(`Valid contract fixture rejected: ${JSON.stringify(validate.errors)}`);
}
if (validate(invalidFixture)) {
  throw new Error("Invalid unknown-action fixture was accepted");
}

console.log(`Structured validation: ${jsonFiles.length} JSON/JSONC files and CI YAML parsed`);
console.log("Operation-request schema fixtures: PASS");
