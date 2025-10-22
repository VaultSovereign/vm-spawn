import fs from "fs";
import path from "path";
import yaml from "js-yaml";
import { evmVerifier } from "../services/anchors/src/evmVerifier";
import { btcVerifier } from "../services/anchors/src/btcVerifier";
import { tsaVerifier } from "../services/anchors/src/tsaVerifier";

type Receipt = {
  batchRoot: `sha256:${string}`;
  anchor?: {
    chain: string;
    [key: string]: unknown;
  };
};

const root = path.resolve(path.join(__dirname, ".."));

function loadCfg(): Record<string, any> {
  const cfgPath = path.join(root, "vmsh/config/anchors.yaml");
  if (!fs.existsSync(cfgPath)) {
    throw new Error("vmsh/config/anchors.yaml missing");
  }
  return yaml.load(fs.readFileSync(cfgPath, "utf8")) as Record<string, any>;
}

async function verify(receiptPath: string, cfg: Record<string, any>) {
  const payload = JSON.parse(fs.readFileSync(receiptPath, "utf8")) as Receipt;
  if (!payload.anchor) {
    return { ok: false, reason: "receipt missing anchor" };
  }

  const anchor = payload.anchor;
  const expected = payload.batchRoot;
  const [ns] = anchor.chain.split(":");

  switch (ns) {
    case "eip155": {
      const entry = cfg.eip155?.default ?? {};
      const verifier = evmVerifier({
        rpcUrl: process.env.EVM_RPC || entry.rpcUrl,
        chainId: Number(process.env.EVM_CHAIN_ID || entry.chainId),
        contract: process.env.EVM_CONTRACT || entry.contract,
        confirmations: Number(process.env.EVM_CONFIRMATIONS || entry.confirmations || 0),
      });
      return verifier.verify(anchor as any, expected);
    }
    case "btc": {
      const entry = cfg.btc?.default ?? {};
      const verifier = btcVerifier({
        rpcUrl: process.env.BTC_RPC || entry.rpcUrl,
        confirmations: Number(process.env.BTC_CONFIRMATIONS || entry.confirmations || 0),
      });
      return verifier.verify(anchor as any, expected);
    }
    case "rfc3161": {
      const entry = cfg.rfc3161?.default ?? {};
      const verifier = tsaVerifier({ trustBundle: entry.trustBundle });
      return verifier.verify(anchor as any, expected);
    }
    default:
      return { ok: false, reason: `no verifier for namespace ${ns}` };
  }
}

(async () => {
  const files = process.argv.slice(2);
  if (!files.length) {
    console.error("usage: ts-node tools/verify-anchor.ts out/receipts/*.json");
    process.exit(2);
  }

  const cfg = loadCfg();
  let failures = 0;

  for (const file of files) {
    try {
      const res = await verify(file, cfg);
      if (res.ok) {
        console.log(`OK   ${file}`);
      } else {
        console.error(`FAIL ${file}: ${res.reason}`);
        failures += 1;
      }
    } catch (err) {
      console.error(`FAIL ${file}: ${(err as Error).message}`);
      failures += 1;
    }
  }

  process.exit(failures ? 1 : 0);
})();
