#!/usr/bin/env ts-node-esm
import fs from 'fs';
import path from 'path';
import yaml from 'js-yaml';

const ROOT = path.resolve(path.join(__dirname, '..'));
const FED_PATH = path.join(ROOT, 'vmsh/config/federation.yaml');
const PEER_PATH = path.join(ROOT, 'vmsh/config/peers.yaml');

function load(p: string) { return yaml.load(fs.readFileSync(p,'utf8')); }

const cmd = process.argv[2];
if (!cmd || cmd === 'help') {
  console.log('vmsh-federation status|sync <namespace>');
  process.exit(0);
}

if (cmd === 'status') {
  const fed = load(FED_PATH) as any;
  const peers = load(PEER_PATH) as any;
  console.log('node:', fed?.mesh?.node_id);
  console.log('peers:', (peers?.peers||[]).map((p:any)=>p.did).join(', '));
  console.log('namespaces:', Object.keys(fed?.namespaces||{}).join(', '));
  process.exit(0);
}

if (cmd === 'sync') {
  const ns = process.argv[3];
  if (!ns) { console.error('missing namespace'); process.exit(2); }
  console.log(`[federation] sync requested for ${ns} (stub)`);
  process.exit(0);
}
