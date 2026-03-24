export const SUPPORTED_METHODS = [
  'getPublicKey',
  'signEvent',
  'nip44.encrypt',
  'nip44.decrypt',
] as const;

const SUPPORTED_METHOD_SET = new Set<string>(SUPPORTED_METHODS);
const VALID_STATUSES = new Set(['draft', 'approved', 'revoked']);

export type SupportedMethod = (typeof SUPPORTED_METHODS)[number];
export type ManifestStatus = 'draft' | 'approved' | 'revoked';

export interface AppManifest {
  slug: string;
  allowed_origins: string[];
  allowed_methods: SupportedMethod[];
  allowed_sign_event_kinds: number[];
  status: ManifestStatus;
  prompt_required_for: SupportedMethod[];
}

export function validateManifest(input: unknown): AppManifest {
  if (!isRecord(input)) {
    throw new Error('manifest must be an object');
  }

  const slug = asTrimmedNonEmptyString(input.slug, 'slug');
  const allowedOrigins = validateOrigins(input.allowed_origins);
  const allowedMethods = validateMethods(input.allowed_methods, 'allowed_methods');
  const allowedSignEventKinds = validateKinds(input.allowed_sign_event_kinds);
  const status = validateStatus(input.status);
  const promptRequiredFor = validateOptionalMethods(
    input.prompt_required_for,
    'prompt_required_for',
  );

  return {
    slug,
    allowed_origins: allowedOrigins,
    allowed_methods: allowedMethods,
    allowed_sign_event_kinds: allowedSignEventKinds,
    status,
    prompt_required_for: promptRequiredFor,
  };
}

function validateOrigins(value: unknown): string[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error('allowed_origins must be a non-empty array');
  }

  const origins = value.map((origin) => asTrimmedNonEmptyString(origin, 'allowed_origins'));
  const canonicalOrigins = origins.map((origin) => {
    const url = tryParseUrl(origin, 'allowed_origins');
    if (url.protocol !== 'https:') {
      throw new Error('allowed_origins must use https');
    }

    if (url.pathname !== '/' || url.search || url.hash) {
      throw new Error('allowed_origins must be exact origins');
    }

    return url.origin;
  });

  return unique(canonicalOrigins);
}

function validateMethods(value: unknown, fieldName: string): SupportedMethod[] {
  if (!Array.isArray(value) || value.length === 0) {
    throw new Error(`${fieldName} must be a non-empty array`);
  }

  const methods = value.map((item) => asTrimmedNonEmptyString(item, fieldName));
  for (const method of methods) {
    if (!SUPPORTED_METHOD_SET.has(method)) {
      throw new Error(`${fieldName} contains unsupported method: ${method}`);
    }
  }

  return unique(methods) as SupportedMethod[];
}

function validateOptionalMethods(
  value: unknown,
  fieldName: string,
): SupportedMethod[] {
  if (value === undefined) {
    return [];
  }

  if (!Array.isArray(value)) {
    throw new Error(`${fieldName} must be an array`);
  }

  if (value.length === 0) {
    return [];
  }

  return validateMethods(value, fieldName);
}

function validateKinds(value: unknown): number[] {
  if (value === undefined) {
    return [];
  }

  if (!Array.isArray(value)) {
    throw new Error('allowed_sign_event_kinds must be an array');
  }

  const kinds = value.map((item) => {
    if (!Number.isInteger(item) || Number(item) < 0) {
      throw new Error('allowed_sign_event_kinds must contain non-negative integers');
    }

    return Number(item);
  });

  return unique(kinds);
}

function validateStatus(value: unknown): ManifestStatus {
  const status = asTrimmedNonEmptyString(value, 'status');
  if (!VALID_STATUSES.has(status)) {
    throw new Error(`status is invalid: ${status}`);
  }

  return status as ManifestStatus;
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

function tryParseUrl(value: string, fieldName: string): URL {
  try {
    return new URL(value);
  } catch {
    throw new Error(`${fieldName} must contain valid URLs`);
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function unique<T>(values: T[]): T[] {
  return [...new Set(values)];
}
