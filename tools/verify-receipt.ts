import * as fs from "fs";
import * as crypto from "crypto";

type Anchor = {
  chain: string;
  contract?: string;
  tx: string;
  block: number;
  ts: number;
  sig?: string;
  memo?: string;
};

type Receipt = {
  eventHash: string;
  batchRoot: string;
  path: string[];
  anchor: Anchor;
  verifier: string;
  integrity: string;
};

function hexFromTagged(tagged: string): Buffer {
  const [algo, hex] = tagged.split(":");
  if (!algo || !hex) throw new Error(`Invalid tagged hash: ${tagged}`);
  if (!/^sha256$/i.test(algo)) throw new Error(`Unsupported hash: ${algo}`);
  if (!/^[0-9a-f]{64}$/i.test(hex)) throw new Error(`Invalid hash hex: ${hex}`);
  return Buffer.from(hex, "hex");
}

function merkleCandidates(leaf: Buffer, path: Buffer[]): Set<string> {
  let candidates = new Set<string>([leaf.toString("hex")]);
  for (const sibling of path) {
    const next = new Set<string>();
    for (const hex of candidates) {
      const node = Buffer.from(hex, "hex");
      const left = crypto.createHash("sha256").update(Buffer.concat([node, sibling])).digest("hex");
      const right = crypto.createHash("sha256").update(Buffer.concat([sibling, node])).digest("hex");
      next.add(left);
      next.add(right);
    }
    candidates = next;
  }
  return candidates;
}

function verifyReceipt(receipt: Receipt) {
  const leaf = hexFromTagged(receipt.eventHash);
  const siblings = receipt.path.map(hexFromTagged);
  const expected = hexFromTagged(receipt.batchRoot).toString("hex");

  if (siblings.length === 0) {
    const ok = leaf.toString("hex") === expected;
    return { ok, computedRoot: `sha256:${leaf.toString("hex")}` };
  }

  const candidates = merkleCandidates(leaf, siblings);
  const ok = candidates.has(expected);
  return { ok, computedRoot: `sha256:${expected}` };
}

function main() {
  const file = process.argv[2];
  if (!file) {
    console.error("Usage: ts-node tools/verify-receipt.ts <receipt.json>");
    process.exit(2);
  }

  const receipt = JSON.parse(fs.readFileSync(file, "utf8")) as Receipt;
  const result = verifyReceipt(receipt);

  if (!result.ok) {
    console.error(`FAIL: expected root ${receipt.batchRoot} is not reachable from provided path.`);
    process.exit(1);
  }

  console.log(`OK  : ${receipt.integrity}`);
  console.log(`root: ${result.computedRoot}`);
  console.log(`anch: ${receipt.anchor.chain} ${receipt.anchor.tx} @ ${receipt.anchor.block}`);
}

main();
