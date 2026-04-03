const AUTH_SCHEME_PREFIX = 'Nostr ';
const NIP98_KIND = 27235;
const MAX_SKEW_SECONDS = 120;

interface Nip98Event {
  pubkey: string;
  kind: number;
  created_at: number;
  tags: string[][];
}

export async function verifyNip98(request: Request): Promise<string> {
  const encodedToken = extractToken(request.headers.get('authorization'));
  const event = parseEvent(encodedToken);

  if (event.kind !== NIP98_KIND) {
    throw unauthorized();
  }

  if (!/^[a-fA-F0-9]{64}$/.test(event.pubkey)) {
    throw unauthorized();
  }

  const now = Math.floor(Date.now() / 1000);
  if (Math.abs(now - event.created_at) > MAX_SKEW_SECONDS) {
    throw unauthorized();
  }

  const expectedUrl = normalizeUrl(request.url);
  const claimedUrl = findTagValue(event.tags, 'u');
  if (!claimedUrl || normalizeUrl(claimedUrl) !== expectedUrl) {
    throw unauthorized();
  }

  const claimedMethod = findTagValue(event.tags, 'method');
  if (!claimedMethod || claimedMethod.toUpperCase() !== request.method.toUpperCase()) {
    throw unauthorized();
  }

  return event.pubkey.toLowerCase();
}

function extractToken(headerValue: string | null): string {
  if (!headerValue || !headerValue.startsWith(AUTH_SCHEME_PREFIX)) {
    throw unauthorized();
  }

  const token = headerValue.slice(AUTH_SCHEME_PREFIX.length).trim();
  if (!token) {
    throw unauthorized();
  }

  return token;
}

function parseEvent(token: string): Nip98Event {
  let jsonText = '';
  try {
    jsonText = atob(token);
  } catch {
    throw unauthorized();
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(jsonText);
  } catch {
    throw unauthorized();
  }

  if (!isRecord(parsed)) {
    throw unauthorized();
  }

  if (
    typeof parsed.pubkey !== 'string' ||
    !Number.isInteger(parsed.kind) ||
    !Number.isInteger(parsed.created_at) ||
    !Array.isArray(parsed.tags)
  ) {
    throw unauthorized();
  }

  const tags = parsed.tags
    .map((tag) =>
      Array.isArray(tag) ? tag.filter((part): part is string => typeof part === 'string') : null,
    )
    .filter((tag): tag is string[] => Array.isArray(tag) && tag.length > 0);

  return {
    pubkey: parsed.pubkey,
    kind: Number(parsed.kind),
    created_at: Number(parsed.created_at),
    tags,
  };
}

function findTagValue(tags: string[][], key: string): string | null {
  const tag = tags.find((current) => current[0] === key);
  return tag && tag.length > 1 ? tag[1] : null;
}

function normalizeUrl(urlText: string): string {
  const url = new URL(urlText);
  url.hash = '';
  return url.toString();
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function unauthorized(): Response {
  return new Response('Unauthorized', { status: 401 });
}
