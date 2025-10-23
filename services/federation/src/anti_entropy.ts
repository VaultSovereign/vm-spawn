import fs from 'fs';
import path from 'path';

export function listLocalReceiptIds(ROOT: string): string[] {
  const dir = path.join(ROOT, 'out/receipts');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.json')).map(f => f.replace(/\.json$/, ''));
}
