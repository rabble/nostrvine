import { type AppManifest, validateManifest } from './manifest-schema';

interface ManifestRow {
  id?: number;
  manifest_json: string;
  created_at?: string;
  updated_at?: string;
}

interface LastInsertMeta {
  last_row_id?: number;
  changes?: number;
}

export type StoredAppManifest = AppManifest & {
  id: number;
  created_at: string;
  updated_at: string;
};

export class ManifestStore {
  constructor(private readonly database: D1Database) {}

  async listApproved(): Promise<StoredAppManifest[]> {
    const result = await this.database
      .prepare(
        `
          SELECT id, manifest_json, created_at, updated_at
          FROM sandbox_apps
          WHERE status = ?
          ORDER BY slug ASC
        `,
      )
      .bind('approved')
      .all<ManifestRow>();

    return (result.results ?? []).flatMap((row) => flattenRow(row));
  }

  async create(manifest: AppManifest): Promise<StoredAppManifest> {
    const now = new Date().toISOString();
    const approvedAt = manifest.status === 'approved' ? now : null;
    const result = await this.database
      .prepare(
        `
          INSERT INTO sandbox_apps (slug, status, manifest_json, updated_at, approved_at)
          VALUES (?, ?, ?, ?, ?)
        `,
      )
      .bind(
        manifest.slug,
        manifest.status,
        JSON.stringify(manifest),
        now,
        approvedAt,
      )
      .run();

    const meta = (result.meta ?? {}) as LastInsertMeta;
    return await this.getByIdOrThrow(Number(meta.last_row_id ?? 0));
  }

  async update(
    id: number,
    manifest: AppManifest,
  ): Promise<StoredAppManifest | null> {
    const now = new Date().toISOString();
    const approvedAt = manifest.status === 'approved' ? now : null;
    const result = await this.database
      .prepare(
        `
          UPDATE sandbox_apps
          SET slug = ?, status = ?, manifest_json = ?, updated_at = ?, approved_at = ?
          WHERE id = ?
        `,
      )
      .bind(
        manifest.slug,
        manifest.status,
        JSON.stringify(manifest),
        now,
        approvedAt,
        id,
      )
      .run();

    const meta = (result.meta ?? {}) as LastInsertMeta;
    if (!meta.changes) {
      return null;
    }

    return await this.getByIdOrThrow(id);
  }

  async revoke(id: number): Promise<StoredAppManifest | null> {
    const current = await this.database
      .prepare(
        `
          SELECT id, manifest_json, created_at, updated_at
          FROM sandbox_apps
          WHERE id = ?
        `,
      )
      .bind(id)
      .first<ManifestRow>();

    if (!current?.manifest_json) {
      return null;
    }

    const revokedManifest = validateManifest({
      ...JSON.parse(current.manifest_json),
      status: 'revoked',
    });
    const now = new Date().toISOString();
    const result = await this.database
      .prepare(
        `
          UPDATE sandbox_apps
          SET status = ?, manifest_json = ?, updated_at = ?, approved_at = ?
          WHERE id = ?
        `,
      )
      .bind('revoked', JSON.stringify(revokedManifest), now, null, id)
      .run();

    const meta = (result.meta ?? {}) as LastInsertMeta;
    if (!meta.changes) {
      return null;
    }

    return await this.getByIdOrThrow(id);
  }

  async listAll(): Promise<StoredAppManifest[]> {
    const result = await this.database
      .prepare(
        `
          SELECT id, manifest_json, created_at, updated_at
          FROM sandbox_apps
          ORDER BY slug ASC
        `,
      )
      .all<ManifestRow>();

    return (result.results ?? []).flatMap((row) => flattenRow(row));
  }

  async getById(id: number): Promise<StoredAppManifest | null> {
    const row = await this.database
      .prepare(
        `
          SELECT id, manifest_json, created_at, updated_at
          FROM sandbox_apps
          WHERE id = ?
        `,
      )
      .bind(id)
      .first<ManifestRow>();

    if (!row) {
      return null;
    }

    const [manifest] = flattenRow(row);
    return manifest ?? null;
  }

  async getBySlug(slug: string): Promise<StoredAppManifest | null> {
    const row = await this.database
      .prepare(
        `
          SELECT id, manifest_json, created_at, updated_at
          FROM sandbox_apps
          WHERE slug = ?
        `,
      )
      .bind(slug)
      .first<ManifestRow>();

    if (!row) {
      return null;
    }

    const [manifest] = flattenRow(row);
    return manifest ?? null;
  }

  async getByIdOrThrow(id: number): Promise<StoredAppManifest> {
    const manifest = await this.getById(id);
    if (!manifest) {
      throw new Error(`App not found: ${id}`);
    }
    return manifest;
  }

  async upsertBySlug(manifest: AppManifest): Promise<{
    manifest: StoredAppManifest;
    operation: 'created' | 'updated';
  }> {
    const existing = await this.getBySlug(manifest.slug);
    if (existing == null) {
      return {
        manifest: await this.create(manifest),
        operation: 'created',
      };
    }

    return {
      manifest: (await this.update(existing.id, manifest))!,
      operation: 'updated',
    };
  }
}

export function createManifestStore(database: D1Database): ManifestStore {
  return new ManifestStore(database);
}

function flattenRow(row: ManifestRow): StoredAppManifest[] {
  if (typeof row.id !== 'number') {
    return [];
  }

  const manifest = validateManifest(JSON.parse(row.manifest_json));
  return [
    {
      id: row.id,
      created_at: row.created_at ?? '',
      updated_at: row.updated_at ?? '',
      ...manifest,
    },
  ];
}
