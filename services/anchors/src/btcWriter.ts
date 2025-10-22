import { AnchorInput, AnchorResult, AnchorWriter } from "./types";
import fetch from "node-fetch";

type Options = {
  rpcUrl: string;
  network: "mainnet" | "testnet" | "regtest";
};

type RpcParams = [method: string, params?: any[]];

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

export function btcWriter(opts: Options): AnchorWriter {
  const rpc = rpcFactory(opts.rpcUrl);

  return {
    async write(input: AnchorInput): Promise<AnchorResult> {
      const payload = `5256${input.batchRoot.replace(/^sha256:/, "")}`; // "RV" + root

      const raw = await rpc("createrawtransaction", [[], [{ data: payload }]]);
      const funded = await rpc("fundrawtransaction", [raw]);
      const signed = await rpc("signrawtransactionwithwallet", [funded.hex]);
      const txid = await rpc("sendrawtransaction", [signed.hex]);

      const tx = await rpc("getrawtransaction", [txid, true]);
      const blockHash = tx.blockhash || (await rpc("getbestblockhash"));
      const block = await rpc("getblock", [blockHash]);

      return {
        anchor: {
          chain: `btc:${opts.network}`,
          tx: txid,
          block: block.height,
          ts: block.time,
          memo: "OP_RETURN:RV+sha256",
        },
      };
    },
  };
}
