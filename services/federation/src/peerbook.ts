import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import yaml from 'js-yaml';
import { PeerIdent } from './types.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT = path.resolve(path.join(__dirname, '../../..'));
const PEER_PATH = path.join(ROOT, 'vmsh/config/peers.yaml');

export class PeerBook {
  peers: Map<string, PeerIdent> = new Map();
  constructor() { this.reload(); }
  reload() {
    if (!fs.existsSync(PEER_PATH)) return;
    const y = yaml.load(fs.readFileSync(PEER_PATH, 'utf8')) as any;
    for (const p of (y?.peers || [])) {
      this.peers.set(p.did, p as PeerIdent);
    }
  }
  get(did: string): PeerIdent | undefined { return this.peers.get(did); }
  all(): PeerIdent[] { return Array.from(this.peers.values()); }
}
