import { btcWriter } from "../src/btcWriter";
import { latestBatch, loadCfg, projectRoot, updateReceipts } from "./_common";

type BtcCfg = {
  rpcUrl: string;
  network: "mainnet" | "testnet" | "regtest";
};

async function main() {
  const root = projectRoot();
  const { id, root: batchRoot } = latestBatch(root);
  const cfg = loadCfg<BtcCfg>(root, "btc");

  const writer = btcWriter({
    rpcUrl: process.env.BTC_RPC || cfg.rpcUrl,
    network: (process.env.BTC_NETWORK as BtcCfg["network"]) || cfg.network || "regtest",
  });

  const result = await writer.write({
    batchId: id,
    batchRoot,
    chain: `btc:${process.env.BTC_NETWORK || cfg.network || "regtest"}`,
  });

  updateReceipts(root, id, result.anchor);
  console.log("BTC anchor recorded:", result.anchor.tx);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
