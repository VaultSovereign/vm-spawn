import yaml from 'js-yaml';
import fs from 'fs';
import path from 'path';

export interface Peer {
  id: string;
  url: string;
}

const PEERS_CONFIG_PATH = path.join(
  __dirname,
  '../../config/peers.yaml',
);

/**
 * Manages the list of trusted peers for the federation service.
 *
 * This class loads the peer list from the `peers.yaml` config file
 * and provides methods to access them, such as selecting a random peer
 * for a gossip session. This decouples the gossip logic from the static
 * configuration.
 */
export class PeerManager {
  private peers: Peer[] = [];

  constructor() {
    this.loadPeers();
  }

  private loadPeers(): void {
    try {
      const fileContents = fs.readFileSync(PEERS_CONFIG_PATH, 'utf8');
      const config = yaml.load(fileContents) as { peers: Peer[] };
      if (config && Array.isArray(config.peers)) {
        this.peers = config.peers;
        console.log(`Loaded ${this.peers.length} peers.`);
      }
    } catch (error) {
      console.error('Error loading peers configuration:', error);
      this.peers = [];
    }
  }

  /**
   * Returns the complete list of loaded peers.
   */
  public getAllPeers(): Peer[] {
    return this.peers;
  }

  /**
   * Selects a random peer from the list, excluding the local node itself if present.
   *
   * @param selfId The ID of the local node to exclude from the selection.
   * @returns A random peer, or null if no other peers are available.
   */
  public getRandomPeer(selfId?: string): Peer | null {
    const eligiblePeers = selfId
      ? this.peers.filter((p) => p.id !== selfId)
      : this.peers;

    if (eligiblePeers.length === 0) {
      return null;
    }

    const randomIndex = Math.floor(Math.random() * eligiblePeers.length);
    return eligiblePeers[randomIndex];
  }
}
