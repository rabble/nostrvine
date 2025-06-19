// ABOUTME: NIP-98 HTTP authentication implementation using Nostr events
// ABOUTME: Validates signed authorization events for secure API access

import { NIP96ErrorCode } from '../types/nip96';

export interface NIP98AuthResult {
  valid: boolean;
  pubkey?: string;
  authEvent?: NostrEvent;
  error?: string;
  errorCode?: NIP96ErrorCode;
}

export interface NostrEvent {
  id: string;
  pubkey: string;
  created_at: number;
  kind: number;
  tags: string[][];
  content: string;
  sig: string;
}

/**
 * Validate NIP-98 HTTP authentication from request headers
 * 
 * NIP-98 uses Nostr events to authenticate HTTP requests:
 * - Kind 27235 events signed by user's private key
 * - Contains method, URL, and timestamp
 * - Prevents replay attacks and ensures request integrity
 */
export async function validateNIP98Auth(
  request: Request,
  maxAge: number = 60000 // 60 seconds default
): Promise<NIP98AuthResult> {
  try {
    // Extract Authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader) {
      return {
        valid: false,
        error: 'Missing Authorization header',
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    // Parse Authorization header (format: "Nostr <base64-encoded-event>")
    if (!authHeader.startsWith('Nostr ')) {
      return {
        valid: false,
        error: 'Invalid Authorization header format. Expected "Nostr <base64-event>"',
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    const eventBase64 = authHeader.substring(6); // Remove "Nostr " prefix
    let authEvent: NostrEvent;

    try {
      const eventJson = atob(eventBase64); // Decode base64
      authEvent = JSON.parse(eventJson);
    } catch (e) {
      return {
        valid: false,
        error: 'Invalid base64 encoding or JSON in authorization event',
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    // Validate event structure
    const validationResult = validateEventStructure(authEvent);
    if (!validationResult.valid) {
      return validationResult;
    }

    // Validate event kind (must be 27235 for HTTP auth)
    if (authEvent.kind !== 27235) {
      return {
        valid: false,
        error: `Invalid event kind ${authEvent.kind}. Expected 27235 for HTTP auth`,
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    // Validate timestamp (prevent replay attacks)
    const now = Math.floor(Date.now() / 1000);
    const eventAge = (now - authEvent.created_at) * 1000; // Convert to milliseconds

    if (eventAge > maxAge) {
      return {
        valid: false,
        error: `Event too old. Age: ${eventAge}ms, max allowed: ${maxAge}ms`,
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    if (authEvent.created_at > now + 300) { // 5 minutes future tolerance
      return {
        valid: false,
        error: 'Event timestamp is too far in the future',
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    // Validate request details in tags
    const methodTag = authEvent.tags.find(tag => tag[0] === 'method');
    const urlTag = authEvent.tags.find(tag => tag[0] === 'u');

    if (!methodTag || methodTag[1] !== request.method) {
      return {
        valid: false,
        error: `Method mismatch. Event: ${methodTag?.[1]}, Request: ${request.method}`,
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    const requestUrl = new URL(request.url);
    const expectedUrl = `${requestUrl.protocol}//${requestUrl.host}${requestUrl.pathname}`;
    
    if (!urlTag || urlTag[1] !== expectedUrl) {
      return {
        valid: false,
        error: `URL mismatch. Event: ${urlTag?.[1]}, Expected: ${expectedUrl}`,
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    // Validate event signature using secp256k1
    const signatureValid = await validateEventSignature(authEvent);
    if (!signatureValid) {
      return {
        valid: false,
        error: 'Invalid event signature',
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }

    // All validation passed
    return {
      valid: true,
      pubkey: authEvent.pubkey,
      authEvent: authEvent
    };

  } catch (error) {
    console.error('NIP-98 authentication error:', error);
    return {
      valid: false,
      error: 'Internal authentication error',
      errorCode: NIP96ErrorCode.SERVER_ERROR
    };
  }
}

/**
 * Validate basic Nostr event structure
 */
function validateEventStructure(event: any): NIP98AuthResult {
  const requiredFields = ['id', 'pubkey', 'created_at', 'kind', 'tags', 'content', 'sig'];
  
  for (const field of requiredFields) {
    if (!(field in event)) {
      return {
        valid: false,
        error: `Missing required field: ${field}`,
        errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
      };
    }
  }

  // Validate field types
  if (typeof event.id !== 'string' || event.id.length !== 64) {
    return {
      valid: false,
      error: 'Invalid event id (must be 64-character hex string)',
      errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
    };
  }

  if (typeof event.pubkey !== 'string' || event.pubkey.length !== 64) {
    return {
      valid: false,
      error: 'Invalid pubkey (must be 64-character hex string)',
      errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
    };
  }

  if (typeof event.created_at !== 'number' || event.created_at <= 0) {
    return {
      valid: false,
      error: 'Invalid created_at timestamp',
      errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
    };
  }

  if (typeof event.kind !== 'number' || event.kind < 0) {
    return {
      valid: false,
      error: 'Invalid event kind',
      errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
    };
  }

  if (!Array.isArray(event.tags)) {
    return {
      valid: false,
      error: 'Invalid tags (must be array)',
      errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
    };
  }

  if (typeof event.content !== 'string') {
    return {
      valid: false,
      error: 'Invalid content (must be string)',
      errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
    };
  }

  if (typeof event.sig !== 'string' || event.sig.length !== 128) {
    return {
      valid: false,
      error: 'Invalid signature (must be 128-character hex string)',
      errorCode: NIP96ErrorCode.AUTHENTICATION_REQUIRED
    };
  }

  return { valid: true };
}

/**
 * Validate Nostr event signature using nostr-tools
 */
async function validateEventSignature(event: NostrEvent): Promise<boolean> {
  try {
    // Import nostr-tools for signature verification
    const { validateEvent, verifyEvent } = await import('nostr-tools');
    
    // First validate event structure
    if (!validateEvent(event)) {
      console.error('Event structure validation failed');
      return false;
    }

    // Verify the cryptographic signature
    const isValid = verifyEvent(event);
    
    if (!isValid) {
      console.error('Signature verification failed:', { eventId: event.id, pubkey: event.pubkey });
      return false;
    }

    console.log('✅ NIP-98 signature verified successfully');
    return true;

  } catch (error) {
    console.error('Signature validation error:', error);
    return false;
  }
}

/**
 * Calculate Nostr event ID according to NIP-01 specification
 */
async function calculateEventId(event: NostrEvent): Promise<string> {
  // Create the serialization array according to NIP-01
  const serialization = [
    0, // Reserved field
    event.pubkey,
    event.created_at,
    event.kind,
    event.tags,
    event.content
  ];

  // Convert to JSON string (no whitespace, UTF-8)
  const jsonString = JSON.stringify(serialization);
  const encoder = new TextEncoder();
  const data = encoder.encode(jsonString);

  // Calculate SHA-256 hash
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = new Uint8Array(hashBuffer);
  
  // Convert to hex string
  return Array.from(hashArray)
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Extract user plan from NIP-98 auth event tags (optional)
 */
export function extractUserPlan(authEvent: NostrEvent): string {
  const planTag = authEvent.tags.find(tag => tag[0] === 'plan');
  return planTag?.[1] || 'free';
}

/**
 * Create error response for authentication failures
 */
export function createAuthErrorResponse(
  error: string,
  errorCode: NIP96ErrorCode = NIP96ErrorCode.AUTHENTICATION_REQUIRED
): Response {
  return new Response(JSON.stringify({
    status: 'error',
    message: error,
    error_code: errorCode
  }), {
    status: 401,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'WWW-Authenticate': 'Nostr'
    }
  });
}