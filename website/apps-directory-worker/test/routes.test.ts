import { describe, expect, it } from 'vitest';

import worker from '../src/index';
import type { Env } from '../src/lib/env';

describe('routes', () => {
  it('GET /v1/apps returns JSON items array', async () => {
    const response = await worker.fetch(
      new Request('https://apps.directory.divine.video/v1/apps'),
      {
        APPS_DB: {} as D1Database,
        ADMIN_ORIGIN: 'https://apps.admin.divine.video',
      } as Env,
    );

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toContain('application/json');

    const json = await response.json();
    expect(json).toEqual({ items: [] });
    expect(Array.isArray(json.items)).toBe(true);
  });
});
