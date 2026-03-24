import { requireAdmin } from './lib/admin-auth';
import type { Env } from './lib/env';
import { validateManifest } from './lib/manifest-schema';
import { createManifestStore } from './lib/manifest-store';

const ADMIN_APP_ID_PATH = /^\/v1\/admin\/apps\/(\d+)$/;
const ADMIN_REVOKE_PATH = /^\/v1\/admin\/apps\/(\d+)\/revoke$/;

const worker = {
  async fetch(request: Request, env: Env): Promise<Response> {
    try {
      const url = new URL(request.url);
      const manifestStore = createManifestStore(env.APPS_DB);

      if (request.method === 'GET' && url.pathname === '/v1/apps') {
        const apps = await manifestStore.listApproved();
        return Response.json({ items: apps });
      }

      if (request.method === 'POST' && url.pathname === '/v1/admin/apps') {
        requireAdmin(request);
        const manifest = validateManifest(await parseJson(request));
        const created = await manifestStore.create(manifest);
        return Response.json(created, { status: 201 });
      }

      if (request.method === 'PUT' && ADMIN_APP_ID_PATH.test(url.pathname)) {
        requireAdmin(request);
        const id = Number(url.pathname.match(ADMIN_APP_ID_PATH)?.[1]);
        if (!Number.isInteger(id) || id <= 0) {
          return new Response('Invalid app id', { status: 400 });
        }

        const manifest = validateManifest(await parseJson(request));
        const updated = await manifestStore.update(id, manifest);
        if (!updated) {
          return new Response('App not found', { status: 404 });
        }

        return Response.json(updated);
      }

      if (request.method === 'POST' && ADMIN_REVOKE_PATH.test(url.pathname)) {
        requireAdmin(request);
        const id = Number(url.pathname.match(ADMIN_REVOKE_PATH)?.[1]);
        if (!Number.isInteger(id) || id <= 0) {
          return new Response('Invalid app id', { status: 400 });
        }

        const revoked = await manifestStore.revoke(id);
        if (!revoked) {
          return new Response('App not found', { status: 404 });
        }

        return Response.json(revoked);
      }

      return new Response('Not found', { status: 404 });
    } catch (error) {
      if (error instanceof Response) {
        return error;
      }

      if (error instanceof SyntaxError) {
        return new Response('Invalid JSON', { status: 400 });
      }

      if (error instanceof Error) {
        return new Response(error.message, { status: 400 });
      }

      return new Response('Internal Server Error', { status: 500 });
    }
  },
};

async function parseJson(request: Request): Promise<unknown> {
  return await request.json();
}

export default worker;
