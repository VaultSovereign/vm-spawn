import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import yaml from 'js-yaml';
import { chooseAnchor } from './conflict.js';
import { evmVerifier } from '../../anchors/src/evmVerifier.js';
import { btcVerifier } from '../../anchors/src/btcVerifier.js';
import { tsaVerifier } from '../../anchors/src/tsaVerifier.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(path.join(__dirname, '../../..'));

function loadAnchorsCfg(): any {
  const cfgPath = path.join(ROOT, 'vmsh/config/anchors.yaml');
  if (!fs.existsSync(cfgPath)) return {};
  return yaml.load(fs.readFileSync(cfgPath, 'utf8')) as any;
}

export async function verifyAnchor(anchor: any, expectedRoot: `sha256:${string}`) {
  const cfg = loadAnchorsCfg();
  const [ns] = (anchor.chain as string).split(':');
  if (ns === 'eip155') {
    const v = evmVerifier({
      rpcUrl: process.env.EVM_RPC || cfg.eip155?.default?.rpcUrl,
      chainId: Number(process.env.EVM_CHAIN_ID || cfg.eip155?.default?.chainId),
      contract: process.env.EVM_CONTRACT || cfg.eip155?.default?.contract,
      confirmations: Number(process.env.EVM_CONFIRMATIONS || cfg.eip155?.default?.confirmations || 0)
    });
    return v.verify(anchor, expectedRoot);
  }
  if (ns === 'btc') {
    const v = btcVerifier({
      rpcUrl: process.env.BTC_RPC || cfg.btc?.default?.rpcUrl,
      confirmations: Number(process.env.BTC_CONFIRMATIONS || cfg.btc?.default?.confirmations || 0)
    });
    return v.verify(anchor, expectedRoot);
  }
  if (ns === 'rfc3161') {
    const v = tsaVerifier({ trustBundle: cfg.rfc3161?.default?.trustBundle });
    return v.verify(anchor, expectedRoot);
  }
  return { ok: false, reason: `no verifier for ${ns}` };
}

export async function importBundle(bundle: any) {
  const receipts = bundle.receipts || [];
  const dir = path.join(ROOT, 'out/receipts');
  fs.mkdirSync(dir, { recursive: true });

  for (const r of receipts) {
    const file = path.join(dir, `${r.integrity?.split('-').slice(2).join('-') || 'unknown'}.json`);
    // merge rule: keep receipt body; reconcile anchor via conflict policy
    let current: any = null;
    if (fs.existsSync(file)) current = JSON.parse(fs.readFileSync(file, 'utf8'));

    // verify anchor if present
    if (r.anchor) {
      const res = await verifyAnchor(r.anchor, r.batchRoot);
      if (!res.ok) {
        console.warn(`[federation] anchor verify failed for ${r.anchor.chain}: ${res.reason}`);
      }
    }

    const merged = current ? { ...current } : r;
    merged.anchor = chooseAnchor(current?.anchor, r.anchor);
    fs.writeFileSync(file, JSON.stringify(merged, null, 2));
  }
}
