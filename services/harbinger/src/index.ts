import express from "express";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import Ajv from "ajv";
import addFormats from "ajv-formats";
import canonicalize from "canonicalize";
import crypto from "crypto";
import YAML from "yaml";
import { nanoid } from "nanoid";
import { globSync } from "glob";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ROOT = path.resolve(__dirname, "../../..");
const SCHEMAS_DIR = path.join(ROOT, "schemas");
const CONFIG_PATH = path.join(ROOT, "vmsh/config/harbinger.yaml");
const OUT_DIR = path.join(ROOT, "out");
const EVENTS_DIR = path.join(OUT_DIR, "events");
const PROV_DIR = path.join(OUT_DIR, "provisional");

fs.mkdirSync(EVENTS_DIR, { recursive: true });
fs.mkdirSync(PROV_DIR, { recursive: true });

// Load config
const config = YAML.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
const schemaPins: Record<string,string> = config?.harbinger?.schemas || {};

// Load manifest and referenced schemas
const manifest = JSON.parse(fs.readFileSync(path.join(SCHEMAS_DIR, "manifest.json"), "utf8"));
const ajv = new Ajv({
  allErrors: true,
  strict: false,
  allowUnionTypes: true,
});
addFormats(ajv);

const validators: Record<string, any> = {};
for (const [uri, file] of Object.entries(manifest)) {
  const schemaPath = path.join(ROOT, file.replace(/^file:\/\//, ""));
  const schema = JSON.parse(fs.readFileSync(schemaPath, "utf8"));
  ajv.addSchema(schema, uri);
}

// Utility: compute sha256:hex of canonicalized JSON
function sha256Tagged(obj: any): string {
  const canonical = canonicalize(obj);
  if (!canonical) throw new Error("JCS canonicalization failed");
  const hash = crypto.createHash("sha256").update(Buffer.from(canonical)).digest("hex");
  return `sha256:${hash}`;
}

// Timestamp skew guard
function withinDrift(ts: number, maxDriftSeconds: number): boolean {
  const now = Math.floor(Date.now() / 1000);
  return Math.abs(now - ts) <= maxDriftSeconds;
}

// Express app
const app = express();
app.use(express.json({ limit: "1mb" }));

app.post("/events", (req, res) => {
  try {
    const env = req.body;
    if (config.harbinger.jcs !== true) throw new Error("Harbinger requires JCS=true");
    // Basic envelope guards
    const required = ["vm:version","event:id","event:type","subject","actor","payload:cid","timestamp","signatures","witness","schema"];
    for (const k of required) if (!(k in env)) return res.status(400).json({ error: `missing ${k}` });

    if (!withinDrift(env.timestamp, config.harbinger.max_drift_seconds || 300)) {
      return res.status(400).json({ error: "timestamp drift too large" });
    }

    // Schema pin check
    const pinned = schemaPins[env["event:type"]];
    if (!pinned) return res.status(400).json({ error: `no schema pin for event:type=${env["event:type"]}` });
    if (env.schema !== pinned) return res.status(400).json({ error: `schema mismatch: expected ${pinned}, got ${env.schema}` });

    // Validate payload against pinned schema
    const validate = ajv.getSchema(pinned);
    if (!validate) return res.status(500).json({ error: `validator not loaded for ${pinned}` });
    if (!validate(env["payload"])) {
      return res.status(400).json({ error: "payload schema validation failed", details: validate.errors });
    }

    // Witness quorum
    const witnesses = Array.isArray(env.witness) ? env.witness : [];
    const minRequired = config.harbinger?.witnesses?.min_required || 1;
    if (witnesses.length < minRequired) {
      return res.status(401).json({ error: `insufficient witnesses (${witnesses.length} < ${minRequired})` });
    }

    // NOTE: Signature verification is implementation-specific (key registry / DID resolver).
    // Phase I skeleton: skip deep DID resolution; ensure field presence.
    if (!Array.isArray(env.signatures) || env.signatures.length < 1) {
      return res.status(401).json({ error: "no signatures supplied" });
    }

    // Compute canonical event hash
    const eventHash = sha256Tagged(env);

    // Persist event & provisional receipt
    const id = env["event:id"] || nanoid();
    fs.writeFileSync(path.join(EVENTS_DIR, `${id}.json`), JSON.stringify(env, null, 2));
    const receivedAt = Math.floor(Date.now() / 1000);
    const provisional = {
      eventHash,
      eventId: id,
      status: "pending",
      receivedAt
    };
    fs.writeFileSync(path.join(PROV_DIR, `${id}.json`), JSON.stringify(provisional, null, 2));

    return res.status(202).json(provisional);
  } catch (e:any) {
    console.error(e);
    return res.status(500).json({ error: e.message || String(e) });
  }
});

app.get("/events/:id", (req, res) => {
  const p = path.join(EVENTS_DIR, `${req.params.id}.json`);
  if (!fs.existsSync(p)) return res.status(404).json({ error: "not found" });
  res.type("application/json").send(fs.readFileSync(p, "utf8"));
});

app.get("/receipts/:id", (req, res) => {
  const filePath = path.join(ROOT, "out/receipts", `${req.params.id}.json`);
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: "not found" });
  res.type("application/json").send(fs.readFileSync(filePath, "utf8"));
});

app.get("/proofs/inclusion", (req, res) => {
  const leaf = typeof req.query.leaf === "string" ? req.query.leaf : undefined;
  const batch = typeof req.query.batch === "string" ? req.query.batch : undefined;
  if (!leaf || !batch) {
    return res.status(400).json({ error: "leaf and batch query parameters are required" });
  }

  const receiptFiles = globSync(path.join(ROOT, "out/receipts", "*.json"));
  for (const file of receiptFiles) {
    const receipt = JSON.parse(fs.readFileSync(file, "utf8"));
    if (receipt.eventHash === leaf && receipt.batchRoot === batch) {
      return res.json({ leaf, batchRoot: batch, path: receipt.path, anchor: receipt.anchor });
    }
  }

  return res.status(404).json({ error: "proof not found" });
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
  console.log(`Harbinger listening on :${port}`);
});
