import { AnchorVerifier } from "./types";
import fetch from "node-fetch";

type Options = {
  rpcUrl: string;
  confirmations?: number;
};

type RpcResponse = {
  result: any;
  error?: { message: string } | null;
};

function rpcFactory(rpcUrl: string) {
  return async (method: string, params: any[] = []) => {
    const res = await fetch(rpcUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ jsonrpc: "1.0", id: "vmsh", method, params }),
    });
    const json = (await res.json()) as RpcResponse;
    if (json.error) {
      throw new Error(json.error.message);
    }
    return json.result;
  };
}

export function btcVerifier(opts: Options): AnchorVerifier {
  const rpc = rpcFactory(opts.rpcUrl);

  return {
    async verify(anchor, expected) {
      try {
        const tx = await rpc("getrawtransaction", [anchor.tx, true]);
        if (!tx) {
          return { ok: false, reason: "tx not found" };
        }

        const want = `5256${expected.replace(/^sha256:/, "")}`.toLowerCase();
        let present = false;

        for (const vout of tx.vout || []) {
          const asm: string = vout.scriptPubKey?.asm || "";
          const match = asm.match(/^OP_RETURN ([0-9a-fA-F]+)$/);
          if (match && match[1].toLowerCase() === want) {
            present = true;
            break;
          }
        }

        if (!present) {
          return { ok: false, reason: "root not in OP_RETURN" };
        }

        const needed = opts.confirmations ?? 0;
        if (needed) {
          const confs = tx.confirmations ?? 0;
          if (confs < needed) {
            return { ok: false, reason: `awaiting ${needed} confs` };
          }
        }

        return { ok: true };
      } catch (err: unknown) {
        if (err instanceof Error) {
          return { ok: false, reason: err.message };
        }
        return { ok: false, reason: "unknown error" };
      }
    },
  };
}
