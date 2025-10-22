import { AnchorVerifier } from "./types";
import { spawnSync } from "node:child_process";
import fs from "fs";
import os from "os";
import path from "path";

type Options = {
  trustBundle?: string;
};

function run(cmd: string, args: string[]): { ok: boolean; out?: Buffer; err?: string } {
  const res = spawnSync(cmd, args, { encoding: "buffer" });
  if (res.status !== 0) {
    return { ok: false, err: res.stderr.toString() || res.stdout.toString() };
  }
  return { ok: true, out: res.stdout };
}

function cleanup(directory: string) {
  try {
    fs.rmSync(directory, { recursive: true, force: true });
  } catch {
    // best effort
  }
}

export function tsaVerifier(opts: Options): AnchorVerifier {
  return {
    async verify(anchor, expected) {
      const sig = anchor.sig;
      if (!sig) {
        return { ok: false, reason: "missing TSA signature blob" };
      }

      const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "vmsh-tsa-verify-"));
      try {
        const tsrPath = path.join(tmp, "response.tsr");
        const rootPath = path.join(tmp, "root.bin");
        fs.writeFileSync(tsrPath, Buffer.from(sig, "base64"));
        fs.writeFileSync(rootPath, Buffer.from(expected.replace(/^sha256:/, ""), "hex"));

        const args = ["ts", "-verify", "-in", tsrPath, "-data", rootPath];
        if (opts.trustBundle) {
          args.push("-CAfile", opts.trustBundle);
        }
        const res = run("openssl", args);
        if (!res.ok) {
          return { ok: false, reason: `openssl verify failed: ${res.err}` };
        }

        return { ok: true };
      } finally {
        cleanup(tmp);
      }
    },
  };
}
