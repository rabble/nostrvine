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
            return null;
          },
          async run() {
            return { success: true };
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
});
