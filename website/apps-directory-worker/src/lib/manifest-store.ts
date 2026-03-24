import { type AppManifest, validateManifest } from './manifest-schema';

interface ManifestRow {
  manifest_json: string;
}

interface LastInsertMeta {
  last_row_id?: number;
  changes?: number;
}

export class ManifestStore {
  constructor(private readonly database: D1Database) {}

  async listApproved(): Promise<AppManifest[]> {
    const result = await this.database
      .prepare(
        `
          SELECT manifest_json
          FROM sandbox_apps
          WHERE status = ?
          ORDER BY slug ASC
        `,
      )
      .bind('approved')
      .all<ManifestRow>();

    return (result.results ?? []).map((row) =>
      validateManifest(JSON.parse(row.manifest_json)),
    );
  }

  async create(manifest: AppManifest): Promise<{ id: number; app: AppManifest }> {
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
    return {
      id: Number(meta.last_row_id ?? 0),
      app: manifest,
    };
  }

  async update(
    id: number,
    manifest: AppManifest,
  ): Promise<{ id: number; app: AppManifest } | null> {
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

    return { id, app: manifest };
  }

  async revoke(id: number): Promise<{ id: number; app: AppManifest } | null> {
    const current = await this.database
      .prepare(
        `
          SELECT manifest_json
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

    return { id, app: revokedManifest };
  }
}

export function createManifestStore(database: D1Database): ManifestStore {
  return new ManifestStore(database);
}
