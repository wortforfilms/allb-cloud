import { describe, expect, it } from "vitest";
import spec from "../contracts/ecosystem-contract.json";
import valid from "../contracts/fixtures/valid-runtime-execute.json";
import invalid from "../contracts/fixtures/invalid-unknown-action.json";
import { APPROVAL_STATUSES, PROTECTED_ACTIONS, SCHEMA_VERSION, isCompatibleSchemaVersion } from "../generated/typescript/contracts";

describe("cross-runtime contract fixtures", () => {
  it("accepts the valid operation fixture", () => {
    expect(valid.schemaVersion).toBe(SCHEMA_VERSION);
    expect(PROTECTED_ACTIONS).toContain(valid.action);
    expect(spec.runtimeOperations).toContain(valid.operation.kind);
  });
  it("accepts supported minors and rejects unknown versions", () => {
    expect(isCompatibleSchemaVersion("1.0.9")).toBe(true);
    expect(isCompatibleSchemaVersion(SCHEMA_VERSION)).toBe(true);
    expect(isCompatibleSchemaVersion("1.2.0")).toBe(false);
    expect(isCompatibleSchemaVersion("2.0.0")).toBe(false);
  });
  it("projects Phase 2 lifecycle domains", () => {
    expect(APPROVAL_STATUSES).toEqual(["Pending", "Approved", "Rejected", "Expired", "Cancelled"]);
  });
  it("rejects an unknown protected action", () => {
    expect(PROTECTED_ACTIONS).not.toContain(invalid.action as never);
  });
});
