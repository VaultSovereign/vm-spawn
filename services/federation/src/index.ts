import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import yaml from 'js-yaml';
import { startServer } from './transport.js';
import { PeerBook } from './peerbook.js';
import { Gossip } from './gossip.js';
import { importBundle } from './apply.js';
import { listLocalReceiptIds } from './anti_entropy.js';
import { BatchAnnounce, BundleRequest, Bundle } from './types.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(path.join(__dirname, '../../..'));
const FED_PATH = path.join(ROOT, 'vmsh/config/federation.yaml');

function loadFederation() {
  if (!fs.existsSync(FED_PATH)) throw new Error('missing vmsh/config/federation.yaml');
  return yaml.load(fs.readFileSync(FED_PATH, 'utf8')) as any;
}

async function main() {
  const peerbook = new PeerBook();
  const gossip = new Gossip(peerbook);
  const fed = loadFederation();
  const listen = (fed.mesh?.listen?.http || '0.0.0.0:8088').split(':');
  const port = Number(listen[listen.length-1]) || 8088;

  startServer(port, {
    onAnnounce: async (msg: BatchAnnounce) => {
      // TODO: signature & DID checks
      console.log('[federation] announce', msg.namespace, msg.batchId, msg.batchRoot);
      // Anti-entropy pull after announce
      const req: BundleRequest = { namespace: msg.namespace, signer: fed.mesh?.node_id || 'unknown', ts: Math.floor(Date.now()/1000) };
      // In a real mesh, choose best peer; here just log. Peer pulls initiated via CLI or timer.
      return;
    },
    onRequest: async (req: BundleRequest) => {
      // Build a bundle from local receipts (simple: send all receipts)
      const dir = path.join(ROOT, 'out/receipts');
      const receipts = fs.existsSync(dir) ? fs.readdirSync(dir).filter(f=>f.endsWith('.json')).map(f=>JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'))) : [];
      const bundle: Bundle = { receipts, anchors: receipts.map(r=>r.anchor).filter(Boolean), signer: fed.mesh?.node_id || 'unknown', ts: Math.floor(Date.now()/1000) };
      return bundle;
    }
  });

  console.log('[federation] node', fed.mesh?.node_id);
  console.log('[federation] peers', peerbook.all().map(p=>p.did).join(', ') || '(none)');
}

main().catch(e => { console.error(e); process.exit(1); });
