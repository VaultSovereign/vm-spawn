import fs from "fs";
import path from "path";
import yaml from "js-yaml";

export function projectRoot(): string {
  return path.resolve(path.join(__dirname, "../../.."));
}

export function latestBatch(root: string): { id: string; root: `sha256:${string}`; file: string } {
  const dir = path.join(root, "out/batches");
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith(".json")).sort() : [];
  if (!files.length) {
    throw new Error("no batches found in out/batches");
  }
  const file = path.join(dir, files[files.length - 1]);
  const payload = JSON.parse(fs.readFileSync(file, "utf8"));
  return { id: payload.id, root: payload.root, file };
}

export function loadCfg<T>(root: string, namespace: "eip155" | "btc" | "rfc3161"): T {
  const cfgPath = path.join(root, "vmsh/config/anchors.yaml");
  if (!fs.existsSync(cfgPath)) {
    throw new Error("vmsh/config/anchors.yaml missing");
  }
  const yamlDoc = yaml.load(fs.readFileSync(cfgPath, "utf8")) as Record<string, any> | undefined;
  return (yamlDoc?.[namespace]?.default ?? {}) as T;
}

export function updateReceipts(root: string, batchId: string, anchor: Record<string, unknown>): void {
  const dir = path.join(root, "out/receipts");
  if (!fs.existsSync(dir)) {
    return;
  }

  for (const file of fs.readdirSync(dir).filter((f) => f.endsWith(".json"))) {
    const target = path.join(dir, file);
    const receipt = JSON.parse(fs.readFileSync(target, "utf8"));
    if (typeof receipt.integrity === "string" && receipt.integrity.includes(batchId)) {
      receipt.anchor = anchor;
      fs.writeFileSync(target, JSON.stringify(receipt, null, 2));
    }
  }
  console.log("Updated receipts with anchor", anchor.chain);
}
