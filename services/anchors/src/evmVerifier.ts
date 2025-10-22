import { AnchorVerifier } from "./types";
import { ethers } from "ethers";

type Options = {
  rpcUrl: string;
  chainId: number;
  contract?: string;
  confirmations?: number;
};

export function evmVerifier(opts: Options): AnchorVerifier {
  const provider = new ethers.JsonRpcProvider(opts.rpcUrl, opts.chainId);
  const iface = new ethers.Interface([
    "event BatchAnchored(bytes32 indexed root, bytes32 indexed batchId, string memo)",
    "function anchor(bytes32 root, bytes32 batchId, string memo, bool persist)",
  ]);

  return {
    async verify(anchor, expected) {
      try {
        const receipt = await provider.getTransactionReceipt(anchor.tx);
        if (!receipt) {
          return { ok: false, reason: "tx not found" };
        }

        const needed = opts.confirmations ?? 0;
        if (needed) {
          const tip = await provider.getBlockNumber();
          if (tip - receipt.blockNumber < needed) {
            return { ok: false, reason: `awaiting ${needed} confs` };
          }
        }

        const want = `0x${expected.replace(/^sha256:/, "")}`.toLowerCase();
        const candidateLogs = opts.contract
          ? receipt.logs.filter((log) => log.address.toLowerCase() === opts.contract!.toLowerCase())
          : receipt.logs;

        for (const log of candidateLogs) {
          try {
            const parsed = iface.parseLog({ topics: log.topics as string[], data: log.data as string }) as unknown as {
              args: { root: string };
            };
            const onchainRoot = parsed.args.root.toLowerCase();
            if (onchainRoot === want) {
              return { ok: true };
            }
          } catch {
            // ignore non-matching log
          }
        }

        const tx = await provider.getTransaction(anchor.tx);
        if (tx) {
          const selector = iface.getFunction("anchor")!.selector;
          const data = tx.data;
          if (typeof data === "string" && data.startsWith(selector)) {
            const decoded = iface.decodeFunctionData("anchor", data);
            const callRoot = (decoded[0] as string).toLowerCase();
            if (callRoot === want) {
              return { ok: true };
            }
          }
        }

        return { ok: false, reason: "root mismatch" };
      } catch (err: unknown) {
        if (err instanceof Error) {
          return { ok: false, reason: err.message };
        }
        return { ok: false, reason: "unknown error" };
      }
    },
  };
}
