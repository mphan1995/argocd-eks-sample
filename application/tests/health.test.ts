import request from "supertest";
import { app } from "../src/main";

describe("health endpoints", () => {
  it("returns healthy on /healthz", async () => {
    const response = await request(app).get("/healthz");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: "ok" });
  });

  it("returns ready on /readyz", async () => {
    const response = await request(app).get("/readyz");

    expect(response.status).toBe(200);
    expect(response.body).toEqual({ status: "ready" });
  });
});
