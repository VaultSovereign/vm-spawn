import { AnchorInput, AnchorResult, AnchorWriter } from "./types";
import { spawnSync } from "node:child_process";
import fs from "fs";
import os from "os";
import path from "path";
import fetch from "node-fetch";

type Options = {
  url: string;
  policyOID?: string;
};

function run(cmd: string, args: string[], input?: Buffer): Buffer {
  const res = spawnSync(cmd, args, { input, encoding: "buffer" });
  if (res.status !== 0) {
    const err = res.stderr.toString() || res.stdout.toString();
    throw new Error(`${cmd} ${args.join(" ")} failed: ${err}`);
  }
  return res.stdout;
}

function cleanup(directory: string) {
  try {
    fs.rmSync(directory, { recursive: true, force: true });
  } catch {
    // ignore best effort cleanup failures
  }
}

export function tsaWriter(opts: Options): AnchorWriter {
  return {
    async write(input: AnchorInput): Promise<AnchorResult> {
      const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "vmsh-tsa-"));
      try {
        const rootBytes = Buffer.from(input.batchRoot.replace(/^sha256:/, ""), "hex");
        const rootPath = path.join(tmp, "root.bin");
        const tsqPath = path.join(tmp, "request.tsq");
        const tsrPath = path.join(tmp, "response.tsr");

        fs.writeFileSync(rootPath, rootBytes);

        const args = ["ts", "-query", "-data", rootPath, "-sha256", "-cert", "-no_nonce", "-out", tsqPath];
        if (opts.policyOID) {
          args.push("-policy", opts.policyOID);
        }
        run("openssl", args);

        const response = await fetch(opts.url, {
          method: "POST",
          headers: { "Content-Type": "application/timestamp-query" },
          body: fs.readFileSync(tsqPath),
        });

        if (!response.ok) {
          throw new Error(`tsa request failed: ${response.status} ${response.statusText}`);
        }

        const buffer = Buffer.from(await response.arrayBuffer());
        fs.writeFileSync(tsrPath, buffer);

        const text = run("openssl", ["ts", "-reply", "-in", tsrPath, "-text"]).toString("utf8");
        const line = text
          .split("\n")
          .map((l) => l.trim())
          .find((l) => l.startsWith("Time stamp:"));

        const ts = line ? Math.floor(new Date(line.replace("Time stamp:", "").trim()).getTime() / 1000) : Math.floor(Date.now() / 1000);

        return {
          anchor: {
            chain: "rfc3161:tsa",
            tx: `tsq:${path.basename(tsqPath)}`,
            block: 0,
            ts,
            sig: buffer.toString("base64"),
            memo: opts.policyOID ? `tsaPolicyOID=${opts.policyOID}` : "",
          },
        };
      } finally {
        cleanup(tmp);
      }
    },
  };
}
