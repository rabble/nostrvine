// ABOUTME: Webhook signature validation utilities for secure webhook processing
// ABOUTME: Ensures webhook requests are authentic using HMAC-SHA256 verification

/**
 * Validate webhook signature using HMAC-SHA256
 * @param payload Raw webhook payload
 * @param signature Signature from webhook headers
 * @param secret Webhook secret from environment
 * @returns Promise<boolean> True if signature is valid
 */
export async function validateWebhookSignature(
  payload: string,
  signature: string,
  secret: string
): Promise<boolean> {
  try {
    // Cloudinary sends signatures in format: sha256=<hash>
    if (!signature.startsWith('sha256=')) {
      console.warn('⚠️ Invalid signature format, expected sha256= prefix');
      return false;
    }

    const expectedHash = signature.substring(7); // Remove 'sha256=' prefix
    
    // Generate HMAC-SHA256 using Web Crypto API
    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const messageData = encoder.encode(payload);

    // Import secret as HMAC key
    const key = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );

    // Generate signature
    const signatureBuffer = await crypto.subtle.sign('HMAC', key, messageData);
    const signatureArray = new Uint8Array(signatureBuffer);
    
    // Convert to hex string
    const actualHash = Array.from(signatureArray)
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');

    // Compare signatures using constant-time comparison
    return constantTimeEquals(expectedHash, actualHash);

  } catch (error) {
    console.error('❌ Webhook signature validation error:', error);
    return false;
  }
}

/**
 * Constant-time string comparison to prevent timing attacks
 * @param a First string
 * @param b Second string
 * @returns boolean True if strings are equal
 */
function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) {
    return false;
  }

  let result = 0;
  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }

  return result === 0;
}