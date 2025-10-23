
import request from "supertest";
import { buildApp } from "../index.hardened.example";

const app = buildApp();

test("GET /health returns ok", async () => {
  const res = await request(app).get("/health");
  expect(res.status).toBe(200);
  expect(res.body.status).toBe("ok");
  expect(res.body.service).toBe("harbinger");
});
