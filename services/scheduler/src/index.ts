import fs from 'fs/promises';
import path from 'path';
import yaml from 'js-yaml';
import crypto from 'crypto';
import { spawn } from 'node:child_process';
import express from 'express';

import { CONFIG, PHI } from './config.js';
import { logger } from './logger.js';
import { NamespacesConfigSchema, NamespacesCfg, State, NamespaceCfg, Cadence } from './schemas.js';
import { anchorsAttempted, anchorsSucceeded, anchorsFailed, backoffState, anchorDuration, register } from './metrics.js';
import { classifyError } from './errors.js';
import { getHealth, recordTick } from './health.js';

function parseEvery(expr: string, baseFast?: number): number {
  const m = expr.match(/^(\d+)(s|m|h|d)$/i);
  if (m) {
    const n = parseInt(m[1], 10);
    return m[2] === 's' ? n : m[2] === 'm' ? n*60 : m[2] === 'h' ? n*3600 : n*86400;
  }
  const k = expr.match(/^(\d+)\*fast$/i);
  if (k && baseFast) return parseInt(k[1], 10) * baseFast;
  throw new Error(`invalid cadence: ${expr}`);
}

// Async I/O helpers
async function fileExists(p: string) { try { await fs.access(p); return true; } catch { return false; } }
async function loadYaml<T>(p: string): Promise<T> {
  const raw = await fs.readFile(p, 'utf8');
  return yaml.load(raw) as T;
}
async function readState(): Promise<State> {
  try { const raw = await fs.readFile(CONFIG.STATE_PATH, 'utf8'); return JSON.parse(raw); }
  catch { return {}; }
}
async function writeState(s: State) { 
  await fs.mkdir(path.dirname(CONFIG.STATE_PATH), { recursive: true });
  await fs.writeFile(CONFIG.STATE_PATH, JSON.stringify(s, null, 2), 'utf8'); 
}
async function latestBatch(): Promise<{ id: string, root: `sha256:${string}` } | null> {
  const dir = path.join(CONFIG.ROOT, 'out/batches');
  try {
    const files = (await fs.readdir(dir)).filter(f => f.endsWith('.json')).sort();
    if (!files.length) return null;
    const raw = await fs.readFile(path.join(dir, files[files.length-1]), 'utf8');
    const j = JSON.parse(raw);
    return { id: j.id, root: j.root };
  } catch { return null; }
}

// Deterministic cache for config with hash-based reload
let currentCfg: NamespacesCfg | null = null;
let cfgHash = '';
async function loadNamespaces(): Promise<NamespacesCfg> {
  const raw = await fs.readFile(CONFIG.NS_PATH, 'utf8');
  const hash = crypto.createHash('sha256').update(raw).digest('hex');
  if (!currentCfg || hash !== cfgHash) {
    currentCfg = NamespacesConfigSchema.parse(yaml.load(raw));
    cfgHash = hash;
    logger.info({ cfgHash }, 'namespaces config loaded');
  }
  return currentCfg!;
}

function periods(ns: NamespaceCfg): Array<['fast'|'strong'|'cold', Cadence, number]> {
  const base = parseEvery(ns.cadence.fast.every);
  const arr: Array<['fast'|'strong'|'cold', Cadence, number]> = [['fast', ns.cadence.fast, base]];
  if (ns.cadence.strong) arr.push(['strong', ns.cadence.strong, parseEvery(ns.cadence.strong.every, base)]);
  if (ns.cadence.cold)   arr.push(['cold', ns.cadence.cold,   parseEvery(ns.cadence.cold.every,   base)]);
  return arr;
}

function callAnchor(target: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const ns = target.split(':')[0];
    let args: string[] = [];
    if (ns === 'eip155') args = ['--prefix','services/anchors','run','anchor:evm'];
    else if (ns === 'btc') args = ['--prefix','services/anchors','run','anchor:btc'];
    else if (ns === 'rfc3161') args = ['--prefix','services/anchors','run','anchor:tsa'];
    else return reject(new Error(`unsupported target ${target}`));
    const child = spawn('npm', args, { cwd: CONFIG.ROOT, stdio: 'inherit', env: process.env });
    child.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`anchor failed code=${code}`)));
  });
}

async function processNamespace(nsName: string, ns: NamespaceCfg, state: State) {
  const list = periods(ns);
  const nsState = state[nsName] ||= { last: {} };
  const batch = await latestBatch();
  if (!batch) return;

  for (const [label, cad, period] of list) {
    const last = nsState.last[label] || 0;
    const due = Math.floor(Date.now()/1000) - last >= period;
    if (!due) continue;

    anchorsAttempted.inc({ namespace: nsName, cadence: label, target: cad.target });
    const started = Date.now();
    try {
      await callAnchor(cad.target);
      const secs = (Date.now() - started) / 1000;
      nsState.last[label] = Math.floor(Date.now()/1000);
      nsState.backoff = 0;
      anchorsSucceeded.inc({ namespace: nsName, cadence: label, target: cad.target });
      anchorDuration.observe({ namespace: nsName, cadence: label, target: cad.target, status: 'success' }, secs);
      backoffState.set({ namespace: nsName }, 0);
      logger.info({ ns: nsName, label, target: cad.target, batch: batch.id }, 'anchor success');
    } catch (e: any) {
      const secs = (Date.now() - started) / 1000;
      anchorsFailed.inc({ namespace: nsName, cadence: label, target: cad.target });
      anchorDuration.observe({ namespace: nsName, cadence: label, target: cad.target, status: 'failure' }, secs);
      const k = Math.min(CONFIG.MAX_BACKOFF, (state[nsName].backoff || 0) + 1);
      state[nsName].backoff = k;
      backoffState.set({ namespace: nsName }, k);
      const typ = classifyError(e);
      const multiplier = typ === 'auth' ? 2.0 : typ === 'validation' ? 0.5 : 1.0;
      const delay = Math.round(CONFIG.BASE_BACKOFF * (PHI ** k) * multiplier);
      logger.error({ err: e.message, ns: nsName, label, target: cad.target, backoff: k, retry_in: delay }, 'anchor failed');
      // Note: delay schedule is implicit via period + last; we can augment with a per-label cooldown if desired.
    }
  }
}

async function tick() {
  recordTick();
  try {
    const nsCfg = await loadNamespaces();
    const state = await readState();
    const tasks = Object.entries(nsCfg.namespaces).map(([name, ns]) => processNamespace(name, ns, state));
    await Promise.allSettled(tasks);
    await writeState(state);
  } catch (e: any) {
    logger.error({ err: e.message }, 'scheduler tick failed');
  }
}

// HTTP: metrics + health
const app = express();
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
app.get('/health', (_req, res) => {
  const h = getHealth();
  res.status(h.status === 'healthy' ? 200 : 503).json(h);
});

async function main() {
  app.listen(CONFIG.METRICS_PORT, () => logger.info({ port: CONFIG.METRICS_PORT }, 'metrics/health server started'));
  logger.info('scheduler starting');
  await tick();
  setInterval(tick, CONFIG.TICK_INTERVAL);
}

main().catch(e => { logger.fatal({ err: e.message }, 'scheduler fatal'); process.exit(1); });
