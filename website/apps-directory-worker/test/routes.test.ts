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

interface AuditRow {
  id: number;
  app_id: number;
  origin: string;
  user_pubkey: string;
  method: string;
  event_kind: number | null;
  decision: string;
  error_code: string | null;
  created_at: string;
}

function createTestEnv(appRows: AppRow[], auditRows: AuditRow[] = []): Env {
  let nextId = appRows.reduce((max, row) => Math.max(max, row.id), 0) + 1;
  let nextAuditId =
    auditRows.reduce((max, row) => Math.max(max, row.id), 0) + 1;

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
                  results: appRows
                    .filter((row) => row.status === status)
                    .sort((left, right) => left.slug.localeCompare(right.slug)),
                };
              }

              return {
                results: [...appRows].sort((left, right) =>
                  left.slug.localeCompare(right.slug),
                ),
              };
            }

            if (sql.includes('FROM sandbox_audit_events')) {
              return { results: auditRows };
            }

            return { results: [] };
          },
          async first() {
            if (sql.includes('FROM sandbox_apps') && sql.includes('WHERE id = ?')) {
              const id = Number(params[0]);
              const row = appRows.find((candidate) => candidate.id === id);
              return row ?? null;
            }

            if (sql.includes('FROM sandbox_apps') && sql.includes('WHERE slug = ?')) {
              const slug = String(params[0] ?? '');
              const row = appRows.find((candidate) => candidate.slug === slug);
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

            if (sql.includes('INSERT INTO sandbox_audit_events')) {
              const row: AuditRow = {
                id: nextAuditId,
                app_id: Number(params[0]),
                origin: String(params[1]),
                user_pubkey: String(params[2]),
                method: String(params[3]),
                event_kind: params[4] == null ? null : Number(params[4]),
                decision: String(params[5]),
                error_code: params[6] == null ? null : String(params[6]),
                created_at: String(params[7]),
              };
              auditRows.push(row);
              nextAuditId += 1;
              return {
                success: true,
                meta: { last_row_id: row.id, changes: 1 },
              };
            }

            return { success: true, meta: { changes: 0 } };
          },
        };
      },
    } as D1Database,
    ADMIN_ORIGIN: 'https://apps.admin.divine.video',
  };
}

function primalManifest(overrides: Record<string, unknown> = {}) {
  return {
    slug: 'primal',
    name: 'Primal',
    tagline: 'A Nostr social app',
    description: 'Browse and post to Nostr.',
    icon_url: 'https://primal.net/icon.png',
    launch_url: 'https://primal.net/app',
    allowed_origins: ['https://primal.net'],
    allowed_methods: ['getPublicKey', 'signEvent'],
    allowed_sign_event_kinds: [1],
    prompt_required_for: [],
    status: 'approved',
    sort_order: 2,
    ...overrides,
  };
}

function primalRow(overrides: Partial<AppRow> = {}): AppRow {
  return {
    id: 1,
    slug: 'primal',
    status: 'approved',
    manifest_json: JSON.stringify(primalManifest()),
    created_at: '2026-03-25T00:00:00.000Z',
    updated_at: '2026-03-25T00:00:00.000Z',
    approved_at: '2026-03-25T00:00:00.000Z',
    ...overrides,
  };
}

function createNip98AuthHeader(options: {
  requestUrl: string;
  method: string;
  pubkey?: string;
  kind?: number;
  createdAt?: number;
  tags?: Array<Array<string>>;
}): string {
  const {
    requestUrl,
    method,
    pubkey = 'f'.repeat(64),
    kind = 27235,
    createdAt = Math.floor(Date.now() / 1000),
    tags = [
      ['u', requestUrl],
      ['method', method],
    ],
  } = options;

  const event = {
    id: '0'.repeat(64),
    pubkey,
    created_at: createdAt,
    kind,
    tags,
    content: '',
    sig: '1'.repeat(128),
  };
  return `Nostr ${Buffer.from(JSON.stringify(event), 'utf8').toString('base64')}`;
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
        primalRow({
          manifest_json: JSON.stringify(
            primalManifest({
              allowed_methods: ['getPublicKey', 'signEvent', 'nip44.decrypt'],
              prompt_required_for: ['nip44.decrypt'],
            }),
          ),
        }),
      ]),
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json).toEqual({
      items: [
        {
          id: 1,
          slug: 'primal',
          name: 'Primal',
          tagline: 'A Nostr social app',
          description: 'Browse and post to Nostr.',
          icon_url: 'https://primal.net/icon.png',
          launch_url: 'https://primal.net/app',
          allowed_origins: ['https://primal.net'],
          allowed_methods: ['getPublicKey', 'signEvent', 'nip44.decrypt'],
          allowed_sign_event_kinds: [1],
          prompt_required_for: ['nip44.decrypt'],
          status: 'approved',
          sort_order: 2,
          created_at: '2026-03-25T00:00:00.000Z',
          updated_at: '2026-03-25T00:00:00.000Z',
        },
      ],
    });
  });

  it('GET /v1/admin/apps returns 403 without access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps'),
      createTestEnv([]),
    );

    expect(response.status).toBe(403);
  });

  it('GET /v1/admin/apps lists stored apps with access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps', {
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      createTestEnv([
        primalRow({
          status: 'draft',
          manifest_json: JSON.stringify(primalManifest({ status: 'draft' })),
          approved_at: null,
        }),
      ]),
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json.items).toEqual([
      {
        id: 1,
        slug: 'primal',
        name: 'Primal',
        tagline: 'A Nostr social app',
        description: 'Browse and post to Nostr.',
        icon_url: 'https://primal.net/icon.png',
        launch_url: 'https://primal.net/app',
        allowed_origins: ['https://primal.net'],
        allowed_methods: ['getPublicKey', 'signEvent'],
        allowed_sign_event_kinds: [1],
        prompt_required_for: [],
        status: 'draft',
        sort_order: 2,
        created_at: '2026-03-25T00:00:00.000Z',
        updated_at: '2026-03-25T00:00:00.000Z',
      },
    ]);
  });

  it('GET /v1/admin/audit-events returns 403 without access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/audit-events'),
      createTestEnv([]),
    );

    expect(response.status).toBe(403);
  });

  it('GET /v1/admin/audit-events returns an empty items list with access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/audit-events', {
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      createTestEnv([]),
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json).toEqual({ items: [] });
  });

  it('POST /v1/audit-events rejects missing authorization headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/audit-events', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          app_id: 1,
          origin: 'https://primal.net',
          method: 'signEvent',
          event_kind: 1,
          decision: 'allowed',
        }),
      }),
      createTestEnv([]),
    );

    expect(response.status).toBe(401);
  });

  it('POST /v1/audit-events rejects invalid NIP-98 tokens', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/audit-events', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Nostr not-valid-base64',
        },
        body: JSON.stringify({
          app_id: 1,
          origin: 'https://primal.net',
          method: 'signEvent',
          event_kind: 1,
          decision: 'allowed',
        }),
      }),
      createTestEnv([]),
    );

    expect(response.status).toBe(401);
  });

  it('POST /v1/audit-events accepts valid payloads and stores rows', async () => {
    const env = createTestEnv([]);
    const requestUrl = 'https://apps.directory.divine.video/v1/audit-events';
    const createdAt = Math.floor(Date.now() / 1000);

    const postResponse = await worker.fetch(
      new Request(requestUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: createNip98AuthHeader({
            requestUrl,
            method: 'POST',
            createdAt,
          }),
        },
        body: JSON.stringify({
          app_id: 1,
          origin: 'https://primal.net',
          method: 'signEvent',
          event_kind: 1,
          decision: 'allowed',
        }),
      }),
      env,
    );

    expect(postResponse.status).toBe(200);
    expect(await postResponse.json()).toEqual({ success: true });

    const listResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/audit-events', {
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      env,
    );

    expect(listResponse.status).toBe(200);
    const listJson = await listResponse.json();
    expect(listJson.items).toHaveLength(1);
    expect(listJson.items[0]).toMatchObject({
      app_id: 1,
      origin: 'https://primal.net',
      user_pubkey: 'f'.repeat(64),
      method: 'signEvent',
      event_kind: 1,
      decision: 'allowed',
      error_code: null,
    });
  });

  it('GET /v1/admin/audit-events lists persisted audit rows with access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/audit-events', {
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      createTestEnv([], [
        {
          id: 7,
          app_id: 1,
          origin: 'https://primal.net',
          user_pubkey: 'a'.repeat(64),
          method: 'nip44.decrypt',
          event_kind: null,
          decision: 'prompt_allowed',
          error_code: null,
          created_at: '2026-03-25T00:00:00.000Z',
        },
      ]),
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json).toEqual({
      items: [
        {
          id: 7,
          app_id: 1,
          origin: 'https://primal.net',
          user_pubkey: 'a'.repeat(64),
          method: 'nip44.decrypt',
          event_kind: null,
          decision: 'prompt_allowed',
          error_code: null,
          created_at: '2026-03-25T00:00:00.000Z',
        },
      ],
    });
  });

  it('POST /v1/admin/apps returns 403 without access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(primalManifest()),
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
        body: JSON.stringify(primalManifest()),
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

  it('POST /v1/admin/apps/bootstrap returns 403 without access identity headers', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/bootstrap', {
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
        body: JSON.stringify(primalManifest()),
      }),
      env,
    );

    expect(response.status).toBe(201);
    const json = await response.json();
    expect(json.id).toBe(1);
    expect(json.name).toBe('Primal');
    expect(json.launch_url).toBe('https://primal.net/app');

    const publicResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      env,
    );
    const publicJson = await publicResponse.json();
    expect(publicJson.items).toHaveLength(1);
    expect(publicJson.items[0].slug).toBe('primal');
  });

  it('PUT /v1/admin/apps/:id updates apps with access identity headers', async () => {
    const env = createTestEnv([primalRow()]);

    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/1', {
        method: 'PUT',
        headers: {
          'content-type': 'application/json',
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
        body: JSON.stringify(
          primalManifest({
            allowed_methods: ['getPublicKey'],
            allowed_sign_event_kinds: [],
          }),
        ),
      }),
      env,
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json.allowed_methods).toEqual(['getPublicKey']);
  });

  it('POST /v1/admin/apps/:id/revoke revokes apps with access identity headers', async () => {
    const env = createTestEnv([primalRow()]);

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
    expect(json.status).toBe('revoked');

    const publicResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      env,
    );
    const publicJson = await publicResponse.json();
    expect(publicJson.items).toEqual([]);
  });

  it('POST /v1/admin/apps/bootstrap seeds the bundled vetted apps', async () => {
    const env = createTestEnv([]);

    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/bootstrap', {
        method: 'POST',
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      env,
    );

    expect(response.status).toBe(200);
    const json = await response.json();
    expect(json.created).toBe(7);
    expect(json.updated).toBe(0);
    expect(json.items).toHaveLength(7);

    const publicResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      env,
    );
    const publicJson = await publicResponse.json();
    expect(publicJson.items.map((item: { slug: string }) => item.slug)).toEqual([
      'flotilla',
      'habla',
      'nostrnests',
      'primal',
      'shopstr',
      'yakihonne',
      'zap-stream',
    ]);
  });

  it('POST /v1/admin/apps/bootstrap updates existing seeded apps without duplicating them', async () => {
    const env = createTestEnv([]);

    await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/bootstrap', {
        method: 'POST',
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      env,
    );

    const secondResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/admin/apps/bootstrap', {
        method: 'POST',
        headers: {
          'CF-Access-Authenticated-User-Email': 'admin@divine.video',
        },
      }),
      env,
    );

    expect(secondResponse.status).toBe(200);
    const secondJson = await secondResponse.json();
    expect(secondJson.created).toBe(0);
    expect(secondJson.updated).toBe(7);
    expect(secondJson.items).toHaveLength(7);

    const publicResponse = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      env,
    );
    const publicJson = await publicResponse.json();
    expect(publicJson.items).toHaveLength(7);
  });
});
