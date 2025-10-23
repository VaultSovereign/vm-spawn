
import { register } from "prom-client";
import "../index.hardened.example"; // side-effect: registers defaults

test("prometheus registry exposes harbinger metrics", async () => {
  const metrics = await register.metrics();
  expect(metrics).toContain("harbinger_process_cpu_");
  expect(metrics).toContain("harbinger_events_validated_total");
  expect(metrics).toContain("harbinger_validation_latency_seconds");
});
