import { type AppManifest, validateManifest } from './manifest-schema';

interface ManifestRow {
  manifest_json: string;
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
}

export function createManifestStore(database: D1Database): ManifestStore {
  return new ManifestStore(database);
}
