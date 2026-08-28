import { describe, expect, it } from "vitest";
import spec from "../contracts/ecosystem-contract.json";
import valid from "../contracts/fixtures/valid-runtime-execute.json";
import invalid from "../contracts/fixtures/invalid-unknown-action.json";
import { PROTECTED_ACTIONS, SCHEMA_VERSION } from "../generated/typescript/contracts";

describe("cross-runtime contract fixtures", () => {
  it("accepts the valid operation fixture", () => {
    expect(valid.schemaVersion).toBe(SCHEMA_VERSION);
    expect(PROTECTED_ACTIONS).toContain(valid.action);
    expect(spec.runtimeOperations).toContain(valid.operation.kind);
  });
  it("rejects an unknown protected action", () => {
    expect(PROTECTED_ACTIONS).not.toContain(invalid.action as never);
  });
});
