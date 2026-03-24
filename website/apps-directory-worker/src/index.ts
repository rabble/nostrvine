import type { Env } from './lib/env';

const worker = {
  async fetch(request: Request, _env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/v1/apps') {
      return Response.json({ items: [] });
    }

    return new Response('Not found', { status: 404 });
  },
};

export default worker;
