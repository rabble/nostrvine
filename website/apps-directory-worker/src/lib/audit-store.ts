const VALID_DECISIONS = new Set([
  'allowed',
  'denied',
  'prompt_allowed',
  'prompt_denied',
  'blocked',
]);

interface AuditRow {
  id?: number;
  app_id?: number;
  origin?: string;
  user_pubkey?: string;
  method?: string;
  event_kind?: number | null;
  decision?: string;
  error_code?: string | null;
  created_at?: string;
}

export interface CreateAuditEventInput {
  app_id: number;
  origin: string;
  user_pubkey: string;
  method: string;
  event_kind: number | null;
  decision: string;
  error_code: string | null;
}

export interface StoredAuditEvent extends CreateAuditEventInput {
  id: number;
  created_at: string;
}

export interface AuditPayload {
  app_id: number;
  origin: string;
  method: string;
  event_kind: number | null;
  decision: string;
  error_code: string | null;
}

export class AuditStore {
  constructor(private readonly database: D1Database) {}

  async insert(input: CreateAuditEventInput): Promise<void> {
    const now = new Date().toISOString();
    await this.database
      .prepare(
        `
          INSERT INTO sandbox_audit_events (
            app_id,
            origin,
            user_pubkey,
            method,
            event_kind,
            decision,
            error_code,
            created_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `,
      )
      .bind(
        input.app_id,
        input.origin,
        input.user_pubkey,
        input.method,
        input.event_kind,
        input.decision,
        input.error_code,
        now,
      )
      .run();
  }

  async listAll(): Promise<StoredAuditEvent[]> {
    const result = await this.database
      .prepare(
        `
          SELECT
            id,
            app_id,
            origin,
            user_pubkey,
            method,
            event_kind,
            decision,
            error_code,
            created_at
          FROM sandbox_audit_events
          ORDER BY created_at DESC, id DESC
        `,
      )
      .all<AuditRow>();

    return (result.results ?? []).flatMap((row) => flattenRow(row));
  }
}

export function createAuditStore(database: D1Database): AuditStore {
  return new AuditStore(database);
}

export function validateAuditPayload(input: unknown): AuditPayload {
  if (!isRecord(input)) {
    throw new Error('audit payload must be an object');
  }

  const appId = asPositiveInteger(input.app_id, 'app_id');
  const origin = asHttpsOrigin(input.origin, 'origin');
  const method = asTrimmedNonEmptyString(input.method, 'method');
  const eventKind = asOptionalNonNegativeInteger(input.event_kind, 'event_kind');
  const decision = asDecision(input.decision, 'decision');
  const errorCode = asOptionalTrimmedString(input.error_code);

  return {
    app_id: appId,
    origin,
    method,
    event_kind: eventKind,
    decision,
    error_code: errorCode,
  };
}

function flattenRow(row: AuditRow): StoredAuditEvent[] {
  if (
    typeof row.id !== 'number' ||
    typeof row.app_id !== 'number' ||
    typeof row.origin !== 'string' ||
    typeof row.user_pubkey !== 'string' ||
    typeof row.method !== 'string' ||
    typeof row.decision !== 'string'
  ) {
    return [];
  }

  return [
    {
      id: row.id,
      app_id: row.app_id,
      origin: row.origin,
      user_pubkey: row.user_pubkey,
      method: row.method,
      event_kind: row.event_kind ?? null,
      decision: row.decision,
      error_code: row.error_code ?? null,
      created_at: row.created_at ?? '',
    },
  ];
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function asPositiveInteger(value: unknown, fieldName: string): number {
  if (!Number.isInteger(value) || Number(value) <= 0) {
    throw new Error(`${fieldName} must be a positive integer`);
  }
  return Number(value);
}

function asOptionalNonNegativeInteger(
  value: unknown,
  fieldName: string,
): number | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (!Number.isInteger(value) || Number(value) < 0) {
    throw new Error(`${fieldName} must be a non-negative integer`);
  }
  return Number(value);
}

function asTrimmedNonEmptyString(value: unknown, fieldName: string): string {
  if (typeof value !== 'string') {
    throw new Error(`${fieldName} must be a string`);
  }
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error(`${fieldName} must not be empty`);
  }
  return trimmed;
}

function asOptionalTrimmedString(value: unknown): string | null {
  if (value === undefined || value === null) {
    return null;
  }
  if (typeof value !== 'string') {
    throw new Error('error_code must be a string when provided');
  }
  const trimmed = value.trim();
  return trimmed || null;
}

function asHttpsOrigin(value: unknown, fieldName: string): string {
  const parsed = new URL(asTrimmedNonEmptyString(value, fieldName));
  if (parsed.protocol !== 'https:') {
    throw new Error(`${fieldName} must use https`);
  }
  return parsed.origin;
}

function asDecision(value: unknown, fieldName: string): string {
  const decision = asTrimmedNonEmptyString(value, fieldName);
  if (!VALID_DECISIONS.has(decision)) {
    throw new Error(`${fieldName} is invalid`);
  }
  return decision;
}
