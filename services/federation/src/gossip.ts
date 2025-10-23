import { BatchAnnounce } from './types.js';
import { postJSON } from './transport.js';
import { PeerBook } from './peerbook.js';

export class Gossip {
  constructor(private peerbook: PeerBook) {}

  async broadcast(ns: string, announce: BatchAnnounce) {
    const peers = this.peerbook.all().filter(p => p.roles.includes('announce'));
    const errors: string[] = [];
    await Promise.all(peers.map(async (p) => {
      try {
        await postJSON(p.url, '/federation/announce', announce);
      } catch (e: any) {
        errors.push(`${p.did}: ${e.message}`);
      }
    }));
    if (errors.length) {
      console.warn(`[federation] announce partial failures: ${errors.join('; ')}`);
    }
  }
}
