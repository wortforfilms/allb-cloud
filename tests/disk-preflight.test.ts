import { execFileSync, spawnSync } from "node:child_process";
import { describe, expect, it } from "vitest";

describe("disk-capacity preflight", () => {
  it("passes for a negligible requirement", () => {
    expect(() =>
      execFileSync(process.execPath, ["scripts/check-disk-space.mjs", "0.001"]),
    ).not.toThrow();
  });

  it("fails before work begins when capacity is insufficient", () => {
    const result = spawnSync(process.execPath, [
      "scripts/check-disk-space.mjs",
      "1000000000",
    ]);
    expect(result.status).toBe(1);
    expect(result.stderr.toString()).toContain("Insufficient disk capacity");
  });
});
