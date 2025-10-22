import fs from "fs";
import path from "path";
import crypto from "crypto";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const ROOT = path.resolve(path.join(__dirname, "../../.."));
const EVENTS_DIR = path.join(ROOT, "out/events");
const PROV_DIR = path.join(ROOT, "out/provisional");
const BATCH_DIR = path.join(ROOT, "out/batches");
const RECEIPTS_DIR = path.join(ROOT, "out/receipts");

for (const dir of [BATCH_DIR, RECEIPTS_DIR]) {
  fs.mkdirSync(dir, { recursive: true });
}

type EventRef = {
  id: string;
  hash: string;
};

function listPendingEvents(): EventRef[] {
  if (!fs.existsSync(PROV_DIR)) return [];

  return fs
    .readdirSync(PROV_DIR)
    .filter((f) => f.endsWith(".json"))
    .map((filename) => {
      const provision = JSON.parse(fs.readFileSync(path.join(PROV_DIR, filename), "utf8"));
      const id = provision.eventId || filename.replace(/\.json$/, "");
      const hash = typeof provision.eventHash === "string" ? provision.eventHash : "";
      return { id, hash };
    })
    .filter((entry) => entry.id && entry.hash && entry.hash.startsWith("sha256:"));
}

function toBuffer(taggedHash: string): Buffer {
  return Buffer.from(taggedHash.replace(/^sha256:/, ""), "hex");
}

function buildMerkle(leaves: Buffer[]) {
  if (leaves.length === 0) {
    throw new Error("cannot build Merkle tree with zero leaves");
  }

  const layers: Buffer[][] = [leaves];
  let level = leaves;

  while (level.length > 1) {
    const next: Buffer[] = [];
    for (let i = 0; i < level.length; i += 2) {
      const left = level[i];
      const right = i + 1 < level.length ? level[i + 1] : left;
      const parent = crypto.createHash("sha256").update(Buffer.concat([left, right])).digest();
      next.push(parent);
    }
    layers.push(next);
    level = next;
  }

  return { root: level[0], layers };
}

function proofForIndex(index: number, layers: Buffer[][]): Buffer[] {
  if (layers.length === 1) return [];

  const siblings: Buffer[] = [];
  let idx = index;
  for (let depth = 0; depth < layers.length - 1; depth++) {
    const layer = layers[depth];
    const isRight = idx % 2 === 1;
    const siblingIndex = isRight ? idx - 1 : idx + 1;
    const sibling = layer[siblingIndex] ?? layer[idx];
    siblings.push(sibling);
    idx = Math.floor(idx / 2);
  }

  return siblings;
}

function writeBatch(batchId: string, root: string, leaves: string[]) {
  fs.writeFileSync(
    path.join(BATCH_DIR, `${batchId}.json`),
    JSON.stringify(
      {
        id: batchId,
        root,
        leaves,
        createdAt: Math.floor(Date.now() / 1000)
      },
      null,
      2
    )
  );
}

function writeReceipt(event: EventRef, batchId: string, batchRoot: string, pathHashes: string[]) {
  const receipt = {
    eventHash: event.hash,
    batchRoot,
    path: pathHashes,
    anchor: {
      chain: "vm:internal",
      contract: undefined,
      tx: `batch:${batchId}`,
      block: 0,
      ts: Math.floor(Date.now() / 1000)
    },
    verifier: "did:vm:arbiter:local-sealer",
    integrity: `vmr1-${batchId}-${event.id}`
  };

  fs.writeFileSync(path.join(RECEIPTS_DIR, `${event.id}.json`), JSON.stringify(receipt, null, 2));
}

function cleanup(event: EventRef) {
  const provPath = path.join(PROV_DIR, `${event.id}.json`);
  if (fs.existsSync(provPath)) fs.unlinkSync(provPath);
}

function sealPendingEvents() {
  const events = listPendingEvents();
  if (events.length === 0) {
    console.log("No events to seal.");
    return;
  }

  const leaves = events.map((event) => toBuffer(event.hash));
  const { root, layers } = buildMerkle(leaves);
  const batchRoot = `sha256:${root.toString("hex")}`;
  const batchId = Math.floor(Date.now() / 1000).toString();

  writeBatch(batchId, batchRoot, events.map((e) => e.hash));

  events.forEach((event, index) => {
    const pathHashes = proofForIndex(index, layers).map((buf) => `sha256:${buf.toString("hex")}`);
    writeReceipt(event, batchId, batchRoot, pathHashes);
    cleanup(event);
  });

  console.log(`Sealed batch ${batchId} with ${events.length} event(s).`);
}

sealPendingEvents();
