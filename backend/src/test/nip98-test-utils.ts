// ABOUTME: Test utilities for creating valid NIP-98 events for testing
// ABOUTME: Generates properly formatted Nostr events for authentication testing

import { finalizeEvent, generateSecretKey, getPublicKey } from 'nostr-tools';

/**
 * Generate a valid NIP-98 event for testing purposes
 */
export function generateTestNIP98Event(options: {
  url: string;
  method: string;
  secretKey?: Uint8Array;
  created_at?: number;
}) {
  const secretKey = options.secretKey || generateSecretKey();
  const publicKey = getPublicKey(secretKey);
  const created_at = options.created_at || Math.floor(Date.now() / 1000);

  const event = {
    kind: 27235,
    created_at,
    tags: [
      ['u', options.url],
      ['method', options.method],
    ],
    content: '',
    pubkey: publicKey,
  };

  return finalizeEvent(event, secretKey);
}

/**
 * Generate a test event with invalid signature
 */
export function generateTestEventWithInvalidSignature(options: {
  url: string;
  method: string;
  created_at?: number;
}) {
  const secretKey = generateSecretKey();
  const publicKey = getPublicKey(secretKey);
  const created_at = options.created_at || Math.floor(Date.now() / 1000);

  // Create a valid event first
  const validEvent = {
    kind: 27235,
    created_at,
    tags: [
      ['u', options.url],
      ['method', options.method],
    ],
    content: '',
    pubkey: publicKey,
  };

  const finalizedEvent = finalizeEvent(validEvent, secretKey);

  // Corrupt the signature to make it invalid
  const invalidSig = 'f'.repeat(128);
  
  return {
    ...finalizedEvent,
    sig: invalidSig, // Invalid signature
  };
}

/**
 * Generate hex strings for testing
 */
export function generateHexString(length: number): string {
  return 'a'.repeat(length);
}