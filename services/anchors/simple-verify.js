// Simple verification script
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get command line arguments
const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('Usage: node simple-verify.js out/receipts/*.json');
  process.exit(1);
}

// Track failures
let failures = 0;

// Check each file
for (const file of files) {
  try {
    const receipt = JSON.parse(fs.readFileSync(file, 'utf8'));
    
    // Basic validation
    if (!receipt.anchor) {
      console.error(`FAIL ${file}: Receipt missing anchor`);
      failures++;
      continue;
    }
    
    // Check anchor chain
    const anchor = receipt.anchor;
    const chain = anchor.chain;
    
    if (!chain) {
      console.error(`FAIL ${file}: Anchor missing chain`);
      failures++;
      continue;
    }
    
    // Basic success message for our mock anchor
    console.log(`OK   ${file} (${chain})`);
  } catch (err) {
    console.error(`FAIL ${file}: ${err.message}`);
    failures++;
  }
}

// Exit with failure count
process.exit(failures ? 1 : 0);