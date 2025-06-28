// ABOUTME: NIP-05 verification handler for mapping Nostr keys to DNS-based identifiers
// ABOUTME: Serves JSON at /.well-known/nostr.json for username verification

interface Env {
  NIP05_STORE: KVNamespace;
  ADMIN_TOKEN?: string;
  [key: string]: any;
}

interface NIP05Response {
  names: Record<string, string>;
  relays?: Record<string, string[]>;
}

interface UserMapping {
  pubkey: string;
  relays?: string[];
  created: number;
  reserved?: boolean;
  claimToken?: string;
}

// Username validation regex - alphanumeric, dash, underscore, dot (case-insensitive)
const USERNAME_REGEX = /^[a-z0-9\-_.]+$/i;

export async function handleNIP05Verification(request: Request, env: Env): Promise<Response> {
  const url = new URL(request.url);
  const name = url.searchParams.get('name');

  // CORS headers required by NIP-05
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Cache-Control': 'public, max-age=300' // 5 minute cache
  };

  // Handle missing name parameter
  if (!name) {
    return new Response(JSON.stringify({
      error: 'Missing name parameter'
    }), {
      status: 400,
      headers
    });
  }

  // Validate username format
  if (!USERNAME_REGEX.test(name)) {
    return new Response(JSON.stringify({
      error: 'Invalid username format'
    }), {
      status: 400,
      headers
    });
  }

  try {
    // Get username mapping from KV store
    const kvKey = `nip05:${name.toLowerCase()}`;
    const mappingData = await env.NIP05_STORE.get<UserMapping>(kvKey, 'json');

    // If no mapping found
    if (!mappingData) {
      return new Response(JSON.stringify({
        names: {},
        relays: {}
      }), {
        status: 200,
        headers
      });
    }

    // Build response
    const response: NIP05Response = {
      names: {
        [name]: mappingData.pubkey
      }
    };

    // Add relays if available
    if (mappingData.relays && mappingData.relays.length > 0) {
      response.relays = {
        [mappingData.pubkey]: mappingData.relays
      };
    }

    return new Response(JSON.stringify(response), {
      status: 200,
      headers
    });

  } catch (error) {
    console.error('NIP-05 verification error:', error);
    return new Response(JSON.stringify({
      error: 'Internal server error'
    }), {
      status: 500,
      headers
    });
  }
}

export async function handleNIP05Registration(request: Request, env: Env): Promise<Response> {
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*'
  };

  try {
    const body = await request.json() as {
      username: string;
      pubkey: string;
      relays?: string[];
      claimToken?: string;
    };

    // Validate required fields
    if (!body.username || !body.pubkey) {
      return new Response(JSON.stringify({
        error: 'Missing required fields: username and pubkey'
      }), {
        status: 400,
        headers
      });
    }

    // Validate username format
    if (!USERNAME_REGEX.test(body.username)) {
      return new Response(JSON.stringify({
        error: 'Invalid username format. Only alphanumeric, dash, underscore, and dot allowed.'
      }), {
        status: 400,
        headers
      });
    }

    // Validate pubkey format (64 character hex)
    if (!/^[a-f0-9]{64}$/i.test(body.pubkey)) {
      return new Response(JSON.stringify({
        error: 'Invalid pubkey format. Must be 64 character hex string.'
      }), {
        status: 400,
        headers
      });
    }

    const username = body.username.toLowerCase();
    const kvKey = `nip05:${username}`;

    // Check if username already exists
    const existing = await env.NIP05_STORE.get<UserMapping>(kvKey, 'json');
    
    if (existing) {
      // Check if it's a reserved username that can be claimed
      if (existing.reserved && existing.claimToken && body.claimToken === existing.claimToken) {
        // Valid claim - update the mapping
        const mapping: UserMapping = {
          pubkey: body.pubkey,
          relays: body.relays || [],
          created: Date.now(),
          reserved: false // Remove reserved status
        };

        await env.NIP05_STORE.put(kvKey, JSON.stringify(mapping));

        return new Response(JSON.stringify({
          success: true,
          username: username,
          identifier: `${username}@openvine.co`
        }), {
          status: 200,
          headers
        });
      }

      return new Response(JSON.stringify({
        error: 'Username already taken'
      }), {
        status: 409,
        headers
      });
    }

    // Check reserved usernames list
    const reservedKey = `reserved:${username}`;
    const isReserved = await env.NIP05_STORE.get(reservedKey);
    
    if (isReserved) {
      return new Response(JSON.stringify({
        error: 'Username is reserved. Original Vine users can claim with verification.'
      }), {
        status: 403,
        headers
      });
    }

    // Create new mapping
    const mapping: UserMapping = {
      pubkey: body.pubkey,
      relays: body.relays || [],
      created: Date.now()
    };

    await env.NIP05_STORE.put(kvKey, JSON.stringify(mapping));

    return new Response(JSON.stringify({
      success: true,
      username: username,
      identifier: `${username}@openvine.co`
    }), {
      status: 201,
      headers
    });

  } catch (error) {
    console.error('NIP-05 registration error:', error);
    return new Response(JSON.stringify({
      error: 'Internal server error'
    }), {
      status: 500,
      headers
    });
  }
}

export function handleNIP05Options(): Response {
  return new Response(null, {
    status: 204,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '86400'
    }
  });
}