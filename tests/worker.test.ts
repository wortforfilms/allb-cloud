import { describe, expect, it } from "vitest";
import worker from "../services/edge_worker/src/index";
import { SCHEMA_VERSION } from "../services/edge_worker/src/generated/contracts";

describe("Edge Worker contract surface", () => {
  it("reports the generated contract version without claiming deployment", async () => {
    const response = await worker.fetch(
      new Request("https://example.invalid/health"),
      { ENVIRONMENT: "test" },
      {} as ExecutionContext,
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      status: "OK",
      service: "maataa-sovereign-worker",
      environment: "test",
      contractVersion: SCHEMA_VERSION,
    });
  });

  it("fails closed for unknown routes", async () => {
    const response = await worker.fetch(
      new Request("https://example.invalid/not-a-route"),
      { ENVIRONMENT: "test" },
      {} as ExecutionContext,
    );
    expect(response.status).toBe(404);
  });
});
