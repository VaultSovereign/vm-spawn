import { describe, it, beforeAll, afterAll, expect } from '@jest/globals';
import { spawn } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import http from 'http';

const ROOT = path.resolve(__dirname, '../../..');

function get(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = '';
      res.on('data', (d) => data += d.toString());
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

describe('Scheduler integration', () => {
  let child: any;
  const fixtures = path.join(ROOT, 'test-fixtures');
  const outBatches = path.join(fixtures, 'out/batches');
  const statePath = path.join(fixtures, 'out/state/scheduler.json');
  const nsPath = path.join(fixtures, 'vmsh/config/namespaces.yaml');

  beforeAll(async () => {
    await fs.mkdir(outBatches, { recursive: true });
    await fs.mkdir(path.dirname(nsPath), { recursive: true });
    await fs.writeFile(path.join(outBatches, '0001.json'), JSON.stringify({
      id: '0001',
      root: 'sha256:' + 'a'.repeat(64)
    }));
    await fs.writeFile(nsPath, `namespaces:\n  test-ns:\n    cadence:\n      fast: { target: 'rfc3161:tsa', every: '5s' }\n`);
    child = spawn('npm', ['run','dev'], {
      cwd: path.join(ROOT, 'services/scheduler'),
      env: {
        ...process.env,
        VMSH_ROOT: fixtures,
        VMSH_NAMESPACES: nsPath,
        VMSH_STATE: statePath,
        VMSH_TICK_MS: '1000',
        METRICS_PORT: '9091'
      },
      stdio: 'inherit'
    });
    await new Promise(r => setTimeout(r, 3500));
  });

  afterAll(async () => {
    try { child.kill(); } catch {}
    await fs.rm(fixtures, { recursive: true, force: true });
  });

  it('updates state', async () => {
    const raw = await fs.readFile(statePath, 'utf8');
    const j = JSON.parse(raw);
    expect(j['test-ns']).toBeDefined();
  });

  it('exposes metrics', async () => {
    const txt = await get('http://127.0.0.1:9091/metrics');
    expect(txt).toContain('vmsh_anchors_attempted_total');
  });

  it('exposes health', async () => {
    const txt = await get('http://127.0.0.1:9091/health');
    expect(txt).toContain('status');
  });
});

