import express from 'express';
import { GossipService } from './gossip';

// A mock Remembrancer client for now. This will be replaced with the actual
// implementation that interacts with the Layer 2 `remembrancer` CLI.
class MockRemembrancer {
  private receipts: any[] = [];
  private merkleRoot: string = 'initial_root_alpha'; // Unique initial root

  async getLocalReceipts() {
    return this.receipts;
  }
  async getMerkleRoot() {
    return this.merkleRoot;
  }
  async updateReceipts(newReceipts: any[]) {
    this.receipts = newReceipts;
    // In a real implementation, this would re-calculate the Merkle root
    // from the new set of receipts.
    const newRootHash = Bun.hash(JSON.stringify(newReceipts));
    this.merkleRoot = `merkle_${newRootHash}`;
  }
}

const app = express();
const port = 8080; // TODO: Load from federation.yaml

const remembrancer = new MockRemembrancer();
const gossipService = new GossipService();

// Middleware to parse JSON bodies
app.use(express.json());

/**
 * Endpoint for peers to fetch the current node's Merkle root.
 * This is the first step in the anti-entropy sync process.
 */
app.get('/merkle-root', async (req, res) => {
  try {
    const merkleRoot = await remembrancer.getMerkleRoot();
    res.json({ merkleRoot });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve Merkle root' });
  }
});

/**
 * Endpoint for peers to fetch the full list of receipts from this node.
 * This is the second step of the sync process, used when Merkle roots differ.
 */
app.get('/receipts', async (req, res) => {
  try {
    const receipts = await remembrancer.getLocalReceipts();
    res.json({ receipts });
  } catch (error) {
    res.status(500).json({ error: 'Failed to retrieve receipts' });
  }
});

/**
 * Starts the federation service.
 */
function startServer() {
  app.listen(port, () => {
    console.log(`Federation service listening on http://localhost:${port}`);
    // Start the gossip protocol to begin syncing with peers
    gossipService.start();
  });
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('Shutting down federation service...');
  gossipService.stop();
  process.exit(0);
});

startServer();
