import axios from 'axios';

// The URL for the local federation service. In a real-world scenario,
// this would be configurable, perhaps via environment variables.
const FEDERATION_SERVICE_URL = 'http://localhost:8080';

/**
 * A client for interacting with the local VaultMesh Federation Service.
 *
 * The Scheduler uses this client to query the federated, canonical view of
 * the network state, rather than relying solely on its own local database.
 * This ensures that the Scheduler's decisions are based on the unified
 * consensus of the entire swarm.
 */
export class FederationClient {
  /**
   * Fetches the unified list of all receipts from the federation service.
   *
   * @returns A promise that resolves to an array of all known receipts.
   */
  public async getUnifiedReceipts(): Promise<any[]> {
    try {
      const response = await axios.get(`${FEDERATION_SERVICE_URL}/receipts`);
      return response.data.receipts || [];
    } catch (error) {
      console.error(
        'Error fetching unified receipts from federation service:',
        error.message,
      );
      // In a real-world scenario, this might trigger a circuit breaker
      // or fall back to using only local data. For now, we return an empty array.
      return [];
    }
  }

  /**
   * Fetches the canonical, federated Merkle root.
   *
   * @returns A promise that resolves to the current Merkle root of the swarm.
   */
  public async getCanonicalMerkleRoot(): Promise<string | null> {
    try {
      const response = await axios.get(
        `${FEDERATION_SERVICE_URL}/merkle-root`,
      );
      return response.data.merkleRoot || null;
    } catch (error) {
      console.error(
        'Error fetching canonical Merkle root from federation service:',
        error.message,
      );
      return null;
    }
  }
}
