import fetch from 'node-fetch';
import express from 'express';
import { BatchAnnounce, BundleRequest, Bundle } from './types.js';

export function startServer(port: number, handlers: {
  onAnnounce: (msg: BatchAnnounce) => Promise<void>,
  onRequest: (msg: BundleRequest) => Promise<Bundle>
}) {
  const app = express();
  app.use(express.json({ limit: '2mb' }));

  app.post('/federation/announce', async (req, res) => {
    try { await handlers.onAnnounce(req.body as BatchAnnounce); res.json({ ok: true }); }
    catch (e: any) { res.status(400).json({ ok: false, error: e.message }); }
  });

  app.post('/federation/request', async (req, res) => {
    try { const bundle = await handlers.onRequest(req.body as BundleRequest); res.json(bundle); }
    catch (e: any) { res.status(400).json({ ok: false, error: e.message }); }
  });

  app.listen(port, () => console.log(`[federation] listening on :${port}`));
}

export async function postJSON(url: string, path: string, body: any) {
  const r = await fetch(`${url}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body)});
  if (!r.ok) throw new Error(`POST ${path} ${r.status}`);
  return await r.json();
}
