// Simple script to test TSA anchoring
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import https from 'https';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get the latest batch from out/batches
const batchesDir = path.join(__dirname, '../../out/batches');
const files = fs.readdirSync(batchesDir).filter(f => f.endsWith('.json')).sort();
if (files.length === 0) {
  console.error('No batches found!');
  process.exit(1);
}

// Read the latest batch
const latestBatch = fs.readFileSync(path.join(batchesDir, files[files.length - 1]), 'utf8');
const batch = JSON.parse(latestBatch);
console.log(`Processing batch: ${batch.id}`);
console.log(`Root: ${batch.root}`);

// Update receipts with a mock anchor
const receiptsDir = path.join(__dirname, '../../out/receipts');
for (const file of fs.readdirSync(receiptsDir).filter(f => f.endsWith('.json'))) {
  const receiptPath = path.join(receiptsDir, file);
  const receipt = JSON.parse(fs.readFileSync(receiptPath, 'utf8'));
  
  if (receipt.integrity && receipt.integrity.includes(batch.id)) {
    receipt.anchor = {
      chain: 'rfc3161:tsa',
      tx: `tsq:${batch.id}`,
      block: 0,
      ts: Math.floor(Date.now() / 1000),
      sig: 'test-signature',
      memo: 'Mock TSA anchor for testing'
    };
    fs.writeFileSync(receiptPath, JSON.stringify(receipt, null, 2));
    console.log(`Updated receipt: ${file}`);
  }
}

console.log('TSA anchor test completed.');