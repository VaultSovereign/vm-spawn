
/**
 * Harbinger — hardened example server
 * Purpose: CloudEvents/governance/oracle schema validation with health + metrics.
 * Tech: TypeScript, Express, AJV, prom-client, pino
 *
 * Drop-in guidance:
 * - If you already have an Express app, copy the middleware/routes only.
 * - Otherwise, you can replace your current index.ts with this file.
 */
import express, { Request, Response, NextFunction } from "express";
import http from "http";
import pino from "pino";
import Ajv, { ValidateFunction } from "ajv";
import addFormats from "ajv-formats";
import { register, collectDefaultMetrics, Counter, Histogram } from "prom-client";

// ---------- Logging ----------
const log = pino({ level: process.env.LOG_LEVEL || "info" });

// ---------- Metrics ----------
collectDefaultMetrics({ prefix: "harbinger_", register });
export const eventsValidated = new Counter({
  name: "harbinger_events_validated_total",
  help: "Total number of events processed by Harbinger",
  labelNames: ["schema", "valid"] as const,
});
export const validationLatency = new Histogram({
  name: "harbinger_validation_latency_seconds",
  help: "Latency of schema validation in seconds",
  buckets: [0.005,0.01,0.025,0.05,0.1,0.25,0.5,1,2,5],
});

// ---------- AJV ----------
const ajv = new Ajv({ allErrors: true, removeAdditional: "failing", strict: false });
addFormats(ajv);

// Example CloudEvents-ish minimal schema (tune/extend via config)
const defaultSchema = {
  $id: "urn:vaultmesh:cloudevent:1",
  type: "object",
  required: ["id", "source", "type", "specversion", "time"],
  properties: {
    id: { type: "string", minLength: 1 },
    source: { type: "string", minLength: 1 },
    type: { type: "string", minLength: 1 },
    specversion: { type: "string", const: "1.0" },
    time: { type: "string", format: "date-time" },
    data: {},
  },
  additionalProperties: true
};

const validators = new Map<string, ValidateFunction>();
function getValidator(schemaName: string): ValidateFunction {
  if (validators.has(schemaName)) return validators.get(schemaName)!;
  const schema = defaultSchema; // Swap in loaded schema map by name if needed.
  const fn = ajv.compile(schema);
  validators.set(schemaName, fn);
  return fn;
}

// ---------- App ----------
export function buildApp() {
  const app = express();
  app.disable("x-powered-by");
  app.use(express.json({ limit: "1mb" }));

  // Health
  app.get("/health", (_req: Request, res: Response) => {
    res.json({
      status: "ok",
      service: "harbinger",
      time: new Date().toISOString(),
      uptime_s: process.uptime(),
      pid: process.pid,
      version: process.env.HARBINGER_VERSION || "0.1.0",
    });
  });

  // Metrics
  app.get("/metrics", async (_req: Request, res: Response) => {
    res.setHeader("Content-Type", register.contentType);
    res.end(await register.metrics());
  });

  // Validate API
  app.post("/validate/:schema?", async (req: Request, res: Response) => {
    const schemaName = (req.params.schema || "urn:vaultmesh:cloudevent:1");
    const endTimer = validationLatency.startTimer();
    try {
      const validate = getValidator(schemaName);
      const ok = validate(req.body);
      endTimer();
      eventsValidated.inc({ schema: schemaName, valid: ok ? "true" : "false" });
      if (!ok) {
        return res.status(400).json({
          valid: false,
          errors: validate.errors || [],
        });
      }
      return res.json({ valid: true });
    } catch (err: any) {
      endTimer();
      eventsValidated.inc({ schema: schemaName, valid: "error" });
      log.error({ err }, "validation error");
      return res.status(500).json({ error: "validation_error", detail: String(err?.message || err) });
    }
  });

  // Error guard
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  app.use((err: any, _req: Request, res: Response, _next: NextFunction) => {
    log.error({ err }, "unhandled error");
    res.status(500).json({ error: "internal_error" });
  });

  return app;
}

if (require.main === module) {
  const app = buildApp();
  const port = Number(process.env.PORT || 8081);
  const server = http.createServer(app);
  server.listen(port, () => log.info({ port }, "Harbinger up"));

  // Graceful shutdown
  const shutdown = (signal: string) => {
    log.warn({ signal }, "shutdown requested");
    server.close(() => {
      log.info("http server closed");
      setTimeout(() => process.exit(0), 50);
    });
    setTimeout(() => {
      log.error("forcing shutdown");
      process.exit(1);
    }, 10_000);
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}
