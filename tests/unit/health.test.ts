import { describe, expect, it } from "vitest";

import { onRequestGet } from "../../functions/api/v1/health";

describe("GET /api/v1/health", () => {
  it("returns the public health status", async () => {
    const response = await onRequestGet(
      {} as Parameters<typeof onRequestGet>[0],
    );

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("application/json");
    expect(await response.json()).toEqual({ status: "ok" });
  });
});
