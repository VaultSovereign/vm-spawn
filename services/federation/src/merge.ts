import canonicalize from 'canonicalize';

/**
 * Implements the deterministic merge logic as specified by Covenant III: Federation.
 *
 * This function takes two arrays of Remembrancer receipts, combines them,
 * removes duplicates, and sorts them into a canonical, deterministic order.
 * This ensures that any two nodes performing the same merge will arrive at
 * the exact same Merkle root, preserving consensus.
 *
 * @param localReceipts The array of receipts from the local node.
 * @param peerReceipts The array of receipts received from a peer node.
 * @returns A new array containing the unified and canonically sorted receipts.
 */
export function deterministicMerge(
  localReceipts: any[],
  peerReceipts: any[],
): any[] {
  const receiptMap = new Map<string, any>();

  // Add all receipts to a map, using their canonicalized form as the key.
  // This automatically handles de-duplication.
  for (const receipt of [...localReceipts, ...peerReceipts]) {
    // A receipt is uniquely identified by its canonical JSON representation.
    const key = canonicalize(receipt);
    if (key && !receiptMap.has(key)) {
      receiptMap.set(key, receipt);
    }
  }

  const unifiedReceipts = Array.from(receiptMap.values());

  // Per FEDERATION_SEMANTICS.md, the canonical sort order is by timestamp,
  // then by the SHA256 hash of the canonicalized receipt to ensure a stable sort
  // for receipts with the same timestamp.
  //
  // NOTE: This sorting implementation MUST remain in sync with the reference
  // implementation in `ops/bin/fed-merge`.
  unifiedReceipts.sort((a, b) => {
    if (a.timestamp < b.timestamp) return -1;
    if (a.timestamp > b.timestamp) return 1;

    // Timestamps are identical, use the canonical hash as a tie-breaker.
    const hashA = canonicalize(a) || '';
    const hashB = canonicalize(b) || '';

    if (hashA < hashB) return -1;
    if (hashA > hashB) return 1;

    return 0;
  });

  return unifiedReceipts;
}
