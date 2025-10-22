import { AnchorInput, AnchorResult, AnchorWriter } from "./types";
import { ethers } from "ethers";

type Options = {
  rpcUrl: string;
  chainId: number;
  contract: string;
  key: string;
  persist?: boolean;
};

export function evmWriter(opts: Options): AnchorWriter {
  const provider = new ethers.JsonRpcProvider(opts.rpcUrl, opts.chainId);
  const wallet = new ethers.Wallet(opts.key, provider);
  const abi = ["function anchor(bytes32 root, bytes32 batchId, string memo, bool persist)"];
  const contract = new ethers.Contract(opts.contract, abi, wallet);

  return {
    async write(input: AnchorInput): Promise<AnchorResult> {
      const rootHex = `0x${input.batchRoot.replace(/^sha256:/, "")}`;
      const batchId32 = ethers.zeroPadValue(ethers.toBeHex(ethers.id(input.batchId)), 32);
      const memo = typeof input.meta?.memo === "string" ? (input.meta.memo as string) : "";

      const tx = await contract.anchor(rootHex, batchId32, memo, Boolean(opts.persist));
      const receipt = await tx.wait();
      const blockNumber = receipt?.blockNumber ?? 0;
      const blk = blockNumber ? await provider.getBlock(blockNumber) : null;
      const ts = blk?.timestamp ? Number(blk.timestamp) : Math.floor(Date.now() / 1000);

      return {
        anchor: {
          chain: `eip155:${opts.chainId}`,
          contract: opts.contract,
          tx: tx.hash,
          block: blockNumber,
          ts,
          memo,
        },
      };
    },
  };
}
