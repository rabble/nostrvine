// ABOUTME: Script to manage reserved usernames from legacy Vine users
// ABOUTME: Allows bulk import and management of reserved username list

interface Env {
  NIP05_STORE: KVNamespace;
  ADMIN_TOKEN?: string;
  [key: string]: any;
}

interface ReservedUsername {
  username: string;
  originalVineId?: string;
  reservedAt: number;
  claimable: boolean;
}

interface BulkImportRequest {
  usernames: string[];
  markAsClaimable?: boolean;
}

export async function handleReservedUsernameImport(request: Request, env: Env): Promise<Response> {
  // Admin authentication check
  const authHeader = request.headers.get('Authorization');
  if (!authHeader || authHeader !== `Bearer ${env.ADMIN_TOKEN}`) {
    return new Response('Unauthorized', { status: 401 });
  }

  try {
    const body = await request.json() as BulkImportRequest;
    
    if (!body.usernames || !Array.isArray(body.usernames)) {
      return new Response(JSON.stringify({
        error: 'Invalid request. usernames array required.'
      }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    let imported = 0;
    let skipped = 0;
    const errors: string[] = [];

    for (const username of body.usernames) {
      try {
        const normalizedUsername = username.toLowerCase().trim();
        
        // Skip invalid usernames
        if (!/^[a-z0-9\-_.]+$/i.test(normalizedUsername)) {
          errors.push(`Invalid username format: ${username}`);
          skipped++;
          continue;
        }

        // Check if already exists
        const nip05Key = `nip05:${normalizedUsername}`;
        const existing = await env.NIP05_STORE.get(nip05Key);
        
        if (existing) {
          skipped++;
          continue;
        }

        // Mark as reserved
        const reservedKey = `reserved:${normalizedUsername}`;
        await env.NIP05_STORE.put(reservedKey, JSON.stringify({
          username: normalizedUsername,
          reservedAt: Date.now(),
          claimable: body.markAsClaimable || false
        }));

        // If claimable, create a reserved mapping with claim token
        if (body.markAsClaimable) {
          const claimToken = generateClaimToken();
          await env.NIP05_STORE.put(nip05Key, JSON.stringify({
            pubkey: '', // Empty until claimed
            relays: [],
            created: Date.now(),
            reserved: true,
            claimToken
          }));
        }

        imported++;
      } catch (error) {
        errors.push(`Error importing ${username}: ${error.message}`);
      }
    }

    return new Response(JSON.stringify({
      success: true,
      imported,
      skipped,
      total: body.usernames.length,
      errors
    }), {
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Bulk import error:', error);
    return new Response(JSON.stringify({
      error: 'Import failed',
      message: error.message
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}

export async function handleCheckReservedUsername(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const username = url.searchParams.get('username');

  if (!username) {
    return new Response(JSON.stringify({
      error: 'Username parameter required'
    }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  const normalizedUsername = username.toLowerCase().trim();
  const reservedKey = `reserved:${normalizedUsername}`;
  const reservedData = await env.NIP05_STORE.get(reservedKey);

  return new Response(JSON.stringify({
    username: normalizedUsername,
    isReserved: !!reservedData,
    data: reservedData ? JSON.parse(reservedData) : null
  }), {
    headers: { 
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*'
    }
  });
}

function generateClaimToken(): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let token = '';
  for (let i = 0; i < 32; i++) {
    token += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return token;
}