export function anchorRank(chain: string): number {
  // Higher is stronger
  if (chain.startsWith('btc:')) return 3;
  if (chain.startsWith('eip155:')) return 2;
  if (chain.startsWith('rfc3161:')) return 1;
  return 0;
}

export function chooseAnchor(a: any, b: any): any {
  if (!a) return b;
  if (!b) return a;
  const ra = anchorRank(a.chain || '');
  const rb = anchorRank(b.chain || '');
  if (ra !== rb) return ra > rb ? a : b;
  // tie-break: higher block wins; then lexical by tx
  if ((a.block || 0) !== (b.block || 0)) return (a.block || 0) > (b.block || 0) ? a : b;
  return String(a.tx || '').localeCompare(String(b.tx || '')) <= 0 ? a : b;
}
