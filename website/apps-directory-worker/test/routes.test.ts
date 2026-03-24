import { describe, expect, it } from 'vitest';

import worker from '../src/index';
import type { Env } from '../src/lib/env';

interface AppRow {
  id: number;
  slug: string;
  status: string;
  manifest_json: string;
  created_at: string;
  updated_at: string;
  approved_at: string | null;
}

function createTestEnv(appRows: AppRow[]): Env {
  let nextId = appRows.reduce((max, row) => Math.max(max, row.id), 0) + 1;

  return {
    APPS_DB: {
      prepare(sql: string) {
        let params: unknown[] = [];
        return {
          bind(...nextParams: unknown[]) {
            params = nextParams;
            return this;
          },
          async all() {
            if (sql.includes('FROM sandbox_apps')) {
              if (sql.includes('WHERE status = ?')) {
                const status = String(params[0] ?? '');
                return {
                  results: appRows.filter((row) => row.status === status),
                };
              }

              return { results: appRows };
            }

            return { results: [] };
          },
          async first() {
            if (sql.includes('FROM sandbox_apps') && sql.includes('WHERE id = ?')) {
              const id = Number(params[0]);
              const row = appRows.find((candidate) => candidate.id === id);
              return row ?? null;
            }

            return null;
          },
          async run() {
            if (sql.includes('INSERT INTO sandbox_apps')) {
              const row: AppRow = {
                id: nextId,
                slug: String(params[0]),
                status: String(params[1]),
                manifest_json: String(params[2]),
                updated_at: String(params[3]),
                approved_at: (params[4] ?? null) as string | null,
                created_at: String(params[3]),
              };
              appRows.push(row);
              nextId += 1;
              return {
                success: true,
                meta: { last_row_id: row.id, changes: 1 },
              };
            }

            if (sql.includes('SET slug = ?, status = ?, manifest_json = ?')) {
              const id = Number(params[5]);
              const row = appRows.find((candidate) => candidate.id === id);
              if (!row) {
                return { success: true, meta: { changes: 0 } };
              }

              row.slug = String(params[0]);
              row.status = String(params[1]);
              row.manifest_json = String(params[2]);
              row.updated_at = String(params[3]);
              row.approved_at = (params[4] ?? null) as string | null;
              return { success: true, meta: { changes: 1 } };
            }

            if (sql.includes('SET status = ?, manifest_json = ?')) {
              const id = Number(params[4]);
              const row = appRows.find((candidate) => candidate.id === id);
              if (!row) {
                return { success: true, meta: { changes: 0 } };
              }

              row.status = String(params[0]);
              row.manifest_json = String(params[1]);
              row.updated_at = String(params[2]);
              row.approved_at = (params[3] ?? null) as string | null;
              return { success: true, meta: { changes: 1 } };
            }

            return { success: true, meta: { changes: 0 } };
          },
        };
      },
    } as D1Database,
    ADMIN_ORIGIN: 'https://apps.admin.divine.video',
  };
}

describe('routes', () => {
  it('GET /v1/apps returns JSON items array', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      createTestEnv([]),
    );

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toContain('application/json');

    const json = await response.json();
    expect(json).toEqual({ items: [] });
    expect(Array.isArray(json.items)).toBe(true);
  });

  it('GET /v1/apps returns approved manifests from storage', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      createTestEnv([
        {
          id: 1,
          slug: 'primal',
          status: 'approved',
          manifest_json: JSON.stringify({
            slug: 'primal',
            allowed_origins: ['https://primal.net'],
            allowed_methods: ['getPublicKey', 'signEvent'],
            allowed_sign_event_kinds: [1],
            status: 'approved',
          }),
          created_at: '2026-03-25T00:00:00.000Z',
          updated_at: '2026-03-25T00:00:00.000Z',
          approved_at: '2026-03-25T00:00:00.000Z',
        },
      ]),
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json).toEqual({
      items: [
        {
          slug: 'primal',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey', 'signEvent'],
          allowed_sign_event_kinds: [1],
          prompt_required_for: [],
          status: 'approved',
        },
      ],
    });
  });

  it('POST /v1/admin/apps returns 403 without access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          slug: 'primal',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey', 'signEvent'],
          allowed_sign_event_kinds: [1],
          status: 'approved',
        }),
      }),
      createTestEnv([]),
    );

    expect(response.status).toBe(403);
  });

  it('PUT /v1/admin/apps/:id returns 403 without access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/1', {
        method: 'PUT',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          slug: 'primal',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey', 'signEvent'],
          allowed_sign_event_kinds: [1],
          status: 'approved',
        }),
      }),
      createTestEnv([]),
    );

    expect(response.status).toBe(403);
  });

  it('POST /v1/admin/apps/:id/revoke returns 403 without access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/1/revoke', {
        method: 'POST',
      }),
      createTestEnv([]),
    );

    expect(response.status).toBe(403);
  });

  it('POST /v1/admin/apps creates apps with access identity headers', async () => {
    const env = createTestEnv([]);
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
        body: JSON.stringify({
          slug: 'primal',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey', 'signEvent'],
          allowed_sign_event_kinds: [1],
          status: 'approved',
        }),
      }),
      env,
    );

    expect(response.status).toBe(201);
    const json = await response.json();
    expect(json.id).toBe(1);

    const publicResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      env,
    );
    const publicJson = await publicResponse.json();
    expect(publicJson.items).toHaveLength(1);
    expect(publicJson.items[0].slug).toBe('primal');
  });

  it('PUT /v1/admin/apps/:id updates apps with access identity headers', async () => {
    const env = createTestEnv([
      {
        id: 1,
        slug: 'primal',
        status: 'approved',
        manifest_json: JSON.stringify({
          slug: 'primal',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey', 'signEvent'],
          allowed_sign_event_kinds: [1],
          status: 'approved',
        }),
        created_at: '2026-03-25T00:00:00.000Z',
        updated_at: '2026-03-25T00:00:00.000Z',
        approved_at: '2026-03-25T00:00:00.000Z',
      },
    ]);

    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/1', {
        method: 'PUT',
        headers: {
          'content-type': 'application/json',
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
        body: JSON.stringify({
          slug: 'primal',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey'],
          allowed_sign_event_kinds: [1],
          status: 'approved',
        }),
      }),
      env,
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json.app.allowed_methods).toEqual(['getPublicKey']);
  });

  it('POST /v1/admin/apps/:id/revoke revokes apps with access identity headers', async () => {
    const env = createTestEnv([
      {
        id: 1,
        slug: 'primal',
        status: 'approved',
        manifest_json: JSON.stringify({
          slug: 'primal',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey', 'signEvent'],
          allowed_sign_event_kinds: [1],
          status: 'approved',
        }),
        created_at: '2026-03-25T00:00:00.000Z',
        updated_at: '2026-03-25T00:00:00.000Z',
        approved_at: '2026-03-25T00:00:00.000Z',
      },
    ]);

    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/1/revoke', {
        method: 'POST',
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      env,
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json.app.status).toBe('revoked');

    const publicResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      env,
    );
    const publicJson = await publicResponse.json();
    expect(publicJson.items).toEqual([]);
  });
});
