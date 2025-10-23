import axios from 'axios';
import { PeerManager, Peer } from './peerManager';
import { deterministicMerge } from './merge';
import { Remembrancer } from './remembrancer'; // Assuming a Remembrancer client

// A mock Remembrancer client for now. This will be replaced with the actual
// implementation that interacts with the Layer 2 `remembrancer` CLI.
class MockRemembrancer {
  async getLocalReceipts() { return []; }
  async getMerkleRoot() { return 'mock_root'; }
  async updateReceipts(receipts: any[]) { /* ... */ }
}

/**
 * Implements the anti-entropy gossip protocol for federated state synchronization.
 *
 * This service periodically selects a random peer and performs the following steps:
 * 1. **Merkle Root Exchange**: Asks the peer for its current Merkle root.
 * 2. **State Comparison**: Compares the peer's root to the local root.
 * 3. **Sync (if needed)**: If the roots differ, it fetches the full list of
 *    receipts from the peer.
 * 4. **Deterministic Merge**: It then performs a deterministic merge of the
 *    local and peer receipts.
 * 5. **State Update**: The newly unified receipt list is saved back to the
 *    local Remembrancer, which computes the new canonical Merkle root.
 */
export class GossipService {
  private peerManager: PeerManager;
  private remembrancer: MockRemembrancer; // TODO: Replace with Remembrancer client
  private gossipInterval: NodeJS.Timeout | null = null;
  private nodeId: string = 'node-alpha'; // TODO: Load from federation.yaml
  private intervalMs: number = 15000;    // TODO: Load from federation.yaml

  constructor() {
    this.peerManager = new PeerManager();
    this.remembrancer = new MockRemembrancer();
  }

  public start() {
    console.log(`Starting gossip service for node "${this.nodeId}"...`);
    this.gossipInterval = setInterval(() => this.runGossip(), this.intervalMs);
  }

  public stop() {
    if (this.gossipInterval) {
      clearInterval(this.gossipInterval);
      this.gossipInterval = null;
      console.log('Gossip service stopped.');
    }
  }

  private async runGossip() {
    const peer = this.peerManager.getRandomPeer(this.nodeId);
    if (!peer) {
      console.log('No eligible peers to gossip with.');
      return;
    }

    console.log(`Initiating gossip with peer: ${peer.id} at ${peer.url}`);

    try {
      // 1. Exchange Merkle roots to check if a sync is necessary.
      const localRoot = await this.remembrancer.getMerkleRoot();
      const peerRoot = (await axios.get(`${peer.url}/merkle-root`)).data.merkleRoot;

      if (localRoot === peerRoot) {
        console.log(`Roots match with ${peer.id}. No sync needed.`);
        return;
      }

      console.log(`Merkle roots differ. Local: ${localRoot}, Peer: ${peerRoot}. Syncing...`);

      // 2. Fetch full receipts from the peer.
      const peerReceipts = (await axios.get(`${peer.url}/receipts`)).data.receipts;
      const localReceipts = await this.remembrancer.getLocalReceipts();

      // 3. Perform the deterministic merge.
      const mergedReceipts = deterministicMerge(localReceipts, peerReceipts);

      // 4. Update the local state.
      await this.remembrancer.updateReceipts(mergedReceipts);
      const newRoot = await this.remembrancer.getMerkleRoot();

      console.log(`Sync with ${peer.id} complete. New Merkle root: ${newRoot}`);

    } catch (error) {
      console.error(`Error during gossip with ${peer.id}:`, error.message);
    }
  }
}
