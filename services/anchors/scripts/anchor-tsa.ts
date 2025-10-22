import { tsaWriter } from "../src/tsaWriter";
import { latestBatch, loadCfg, projectRoot, updateReceipts } from "./_common";

type TsaCfg = {
  url: string;
  policyOID?: string;
};

async function main() {
  const root = projectRoot();
  const { id, root: batchRoot } = latestBatch(root);
  const cfg = loadCfg<TsaCfg>(root, "rfc3161");

  const writer = tsaWriter({
    url: process.env.TSA_URL || cfg.url,
    policyOID: process.env.TSA_POLICY_OID || cfg.policyOID,
  });

  const result = await writer.write({
    batchId: id,
    batchRoot,
    chain: "rfc3161:tsa",
  });

  updateReceipts(root, id, result.anchor);
  console.log("TSA anchor recorded.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
