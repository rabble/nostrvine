import type { Env } from './lib/env';
import { createManifestStore } from './lib/manifest-store';

const worker = {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/v1/apps') {
      const manifestStore = createManifestStore(env.APPS_DB);
      const apps = await manifestStore.listApproved();
      return Response.json({ items: apps });
    }

    return new Response('Not found', { status: 404 });
  },
};

export default worker;
