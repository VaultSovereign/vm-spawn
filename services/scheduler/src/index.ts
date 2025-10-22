import fs from "fs";
import path from "path";
import yaml from "js-yaml";
import { spawn } from "node:child_process";

type Cadence = { target:string; every:string; confirmations?:number; policyOID?:string };
type NS = {
  description?: string;
  witnesses?: { min_required:number; allowlist:string[] };
  schema_policy?: { allow:string[] };
  cadence: { fast:Cadence; strong?:Cadence; cold?:Cadence };
};
type NamespacesCfg = { namespaces: Record<string, NS> };
type State = Record<string, { last: { fast?:number; strong?:number; cold?:number }, backoff?: number }>;

const ROOT = path.resolve(path.join(__dirname, "../../.."));
const NS_PATH = path.join(ROOT, "vmsh/config/namespaces.yaml");
const ANC_PATH = path.join(ROOT, "vmsh/config/anchors.yaml");
const STATE_PATH = path.join(ROOT, "out/state/scheduler.json");

// util
const now = () => Math.floor(Date.now()/1000);
const ensureDir = (d:string) => fs.mkdirSync(d, { recursive: true });
ensureDir(path.dirname(STATE_PATH));

function loadYaml<T>(p:string): T {
  if (!fs.existsSync(p)) throw new Error(`missing config: ${p}`);
  return yaml.load(fs.readFileSync(p, "utf8")) as T;
}
function parseEvery(expr:string, baseFast?:number): number {
  // "89s" | "5m" | "1h" | "1d" | "34*fast"
  const m = expr.match(/^(\d+)(s|m|h|d)$/i);
  if (m) {
    const n = parseInt(m[1],10);
    return m[2]==="s" ? n : m[2]==="m" ? n*60 : m[2]==="h" ? n*3600 : n*86400;
  }
  const k = expr.match(/^(\d+)\*fast$/i);
  if (k && baseFast) return parseInt(k[1],10) * baseFast;
  throw new Error(`invalid cadence: ${expr}`);
}
function readState(): State {
  if (!fs.existsSync(STATE_PATH)) return {};
  return JSON.parse(fs.readFileSync(STATE_PATH,"utf8"));
}
function writeState(s:State) { fs.writeFileSync(STATE_PATH, JSON.stringify(s,null,2)); }

function latestBatchForNamespace(ns: string) {
  // Simple mapping: use global batches, assume last sealed batch applies to all; upgrade later to sub-trees.
  const dir = path.join(ROOT, "out/batches");
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f=>f.endsWith(".json")).sort() : [];
  if (!files.length) return null;
  const file = path.join(dir, files[files.length-1]);
  const j = JSON.parse(fs.readFileSync(file,"utf8"));
  return { id: j.id as string, root: j.root as string };
}

function callAnchor(target:string, batchId:string, root:string): Promise<void> {
  return new Promise((resolve, reject) => {
    const [ns, net] = target.split(":");
    let cmd = ""; let args: string[] = [];
    if (ns === "eip155")      { cmd = "npm"; args = ["--prefix","services/anchors","run","anchor:evm"]; }
    else if (ns === "btc")    { cmd = "npm"; args = ["--prefix","services/anchors","run","anchor:btc"]; }
    else if (ns === "rfc3161"){ cmd = "npm"; args = ["--prefix","services/anchors","run","anchor:tsa"]; }
    else return reject(new Error(`unsupported target ${target}`));

    const child = spawn(cmd, args, { stdio:"inherit", cwd: ROOT, env: process.env });
    child.on("exit", code => code===0 ? resolve() : reject(new Error(`anchor failed: ${target} code=${code}`)));
  });
}

async function tick() {
  const nsCfg = loadYaml<NamespacesCfg>(NS_PATH);
  const state = readState();

  for (const [nsName, ns] of Object.entries(nsCfg.namespaces)) {
    const baseFast = parseEvery(ns.cadence.fast.every);
    const cadences: Array<["fast"|"strong"|"cold", Cadence, number]> = [
      ["fast", ns.cadence.fast, baseFast]
    ];
    if (ns.cadence.strong) cadences.push(["strong", ns.cadence.strong, parseEvery(ns.cadence.strong.every, baseFast)]);
    if (ns.cadence.cold)   cadences.push(["cold",   ns.cadence.cold,   parseEvery(ns.cadence.cold.every, baseFast)]);

    const nsState = state[nsName] ||= { last: {} };

    for (const [label, cad, period] of cadences) {
      const last = nsState.last[label] || 0;
      if (now() - last < period) continue;

      const batch = latestBatchForNamespace(nsName);
      if (!batch) continue;

      // Emit anchor.attempt (Phase-I envelope pattern) — optional
      try {
        await callAnchor(cad.target, batch.id, batch.root);
        nsState.last[label] = now();
        nsState.backoff = 0;
        // Emit anchor.success event — optional
      } catch (e) {
        // Emit anchor.fail event — optional
        const k = Math.min(7, (nsState.backoff || 0) + 1); // cap backoff
        nsState.backoff = k;
        // Retry after φ-backoff (~1.618^k * 5s)
        const delay = Math.round(5 * Math.pow(1.618, k));
        console.error(`[${nsName}/${label}] anchor failed: ${(e as Error).message}; backoff ${delay}s`);
      }
    }
  }
  writeState(state);
}

(async function main(){
  console.log("Scheduler: per-namespace cadence driver started.");
  // coarse loop each 10s; fine-grained timing computed per-namespace per-cadence
  setInterval(tick, 10_000);
  await tick();
})();