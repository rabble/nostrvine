// ABOUTME: NIP-98 authentication validation for Nostr-based API access
// ABOUTME: Verifies event signatures and validates request metadata

import { validateEvent, verifyEvent } from 'nostr-tools';

export interface NIP98Event {
  id: string;
  pubkey: string;
  created_at: number;
  kind: number;
  tags: string[][];
  content: string;
  sig: string;
}

export class NIP98AuthError extends Error {
  constructor(message: string, public code: string = 'auth_failed') {
    super(message);
    this.name = 'NIP98AuthError';
  }
}

/**
 * Validates a NIP-98 authentication event
 * @param authHeader The Authorization header value
 * @param requestUrl The full URL of the request being authenticated
 * @param method The HTTP method (defaults to POST)
 * @returns The validated Nostr event
 * @throws NIP98AuthError if validation fails
 */
export async function validateNIP98Event(
  authHeader: string,
  requestUrl: string,
  method: string = 'POST'
): Promise<NIP98Event> {
  try {
    // Parse authorization header
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Nostr') {
      throw new NIP98AuthError('Invalid authorization scheme');
    }

    // Decode base64 event
    let eventData: NIP98Event;
    try {
      eventData = JSON.parse(atob(parts[1]));
    } catch (e) {
      throw new NIP98AuthError('Invalid base64 encoded event');
    }

    // Validate event kind
    if (eventData.kind !== 27235) {
      throw new NIP98AuthError(`Invalid event kind: expected 27235, got ${eventData.kind}`);
    }

    // Check timestamp (within 60 seconds)
    const now = Math.floor(Date.now() / 1000);
    const timeDiff = Math.abs(now - eventData.created_at);
    if (timeDiff > 60) {
      throw new NIP98AuthError(
        `Event timestamp out of range: ${timeDiff}s difference (max 60s)`
      );
    }

    // Find and validate required tags
    const urlTag = eventData.tags.find(tag => tag[0] === 'u');
    const methodTag = eventData.tags.find(tag => tag[0] === 'method');

    if (!urlTag || urlTag.length < 2) {
      throw new NIP98AuthError('Missing or invalid URL tag');
    }

    if (!methodTag || methodTag.length < 2) {
      throw new NIP98AuthError('Missing or invalid method tag');
    }

    // Verify URL matches
    if (urlTag[1] !== requestUrl) {
      throw new NIP98AuthError(
        `URL mismatch: expected ${requestUrl}, got ${urlTag[1]}`
      );
    }

    // Verify method matches
    if (methodTag[1].toUpperCase() !== method.toUpperCase()) {
      throw new NIP98AuthError(
        `Method mismatch: expected ${method}, got ${methodTag[1]}`
      );
    }

    // Validate event structure and signature
    if (!validateEvent(eventData)) {
      throw new NIP98AuthError('Event validation failed');
    }

    if (!verifyEvent(eventData)) {
      throw new NIP98AuthError('Invalid event signature');
    }

    return eventData;
  } catch (error) {
    if (error instanceof NIP98AuthError) {
      throw error;
    }
    throw new NIP98AuthError(
      `NIP-98 validation failed: ${error instanceof Error ? error.message : 'Unknown error'}`
    );
  }
}

/**
 * Extracts pubkey from a validated NIP-98 event in the Authorization header
 * @param authHeader The Authorization header value
 * @returns The pubkey or null if invalid
 */
export function extractPubkeyFromAuth(authHeader: string): string | null {
  try {
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Nostr') {
      return null;
    }

    const eventData = JSON.parse(atob(parts[1])) as NIP98Event;
    return eventData.pubkey || null;
  } catch {
    return null;
  }
}