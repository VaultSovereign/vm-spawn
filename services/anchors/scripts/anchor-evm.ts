import { evmWriter } from "../src/evmWriter";
import { latestBatch, loadCfg, projectRoot, updateReceipts } from "./_common";

type EvmCfg = {
  rpcUrl: string;
  chainId: number;
  contract: string;
  key: string;
  persist?: boolean;
};

async function main() {
  const root = projectRoot();
  const { id, root: batchRoot } = latestBatch(root);
  const cfg = loadCfg<EvmCfg>(root, "eip155");

  const writer = evmWriter({
    rpcUrl: process.env.EVM_RPC || cfg.rpcUrl,
    chainId: Number(process.env.EVM_CHAIN_ID || cfg.chainId),
    contract: process.env.EVM_CONTRACT || cfg.contract,
    key: process.env.EVM_ANCHOR_KEY || cfg.key,
    persist: process.env.EVM_PERSIST ? process.env.EVM_PERSIST === "true" : cfg.persist,
  });

  const result = await writer.write({
    batchId: id,
    batchRoot,
    chain: `eip155:${process.env.EVM_CHAIN_ID || cfg.chainId}`,
  });

  updateReceipts(root, id, result.anchor);
  console.log("EVM anchor recorded:", result.anchor.tx);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
