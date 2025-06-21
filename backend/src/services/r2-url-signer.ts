// ABOUTME: R2 URL signing service for secure video access with short-lived URLs
// ABOUTME: Generates presigned URLs for R2 objects to prevent hotlinking

export interface SignedUrlOptions {
  expiresIn?: number; // Seconds until expiration (default: 300 = 5 minutes)
  responseContentType?: string; // Force a specific Content-Type in response
}

export class R2UrlSigner {
  constructor(
    private r2Bucket: R2Bucket,
    private baseUrl: string // Public URL base for R2 bucket
  ) {}

  /**
   * Generate a signed URL for a video file
   */
  async getSignedUrl(key: string, options: SignedUrlOptions = {}): Promise<string> {
    const { expiresIn = 300, responseContentType } = options;
    
    try {
      // Check if object exists first
      const object = await this.r2Bucket.head(key);
      if (!object) {
        throw new Error(`Object not found: ${key}`);
      }

      // For R2, we'll use the Worker to proxy requests with authentication
      // This provides better control than R2's built-in presigned URLs
      const timestamp = Date.now();
      const expiry = timestamp + (expiresIn * 1000);
      const signature = await this.generateSignature(key, expiry);
      
      // Construct signed URL with query parameters
      const url = new URL(`${this.baseUrl}/${key}`);
      url.searchParams.set('X-Signature', signature);
      url.searchParams.set('X-Expires', expiry.toString());
      if (responseContentType) {
        url.searchParams.set('response-content-type', responseContentType);
      }
      
      return url.toString();
    } catch (error) {
      console.error(`Failed to generate signed URL for ${key}:`, error);
      throw error;
    }
  }

  /**
   * Generate signed URLs for multiple files in parallel
   */
  async getSignedUrls(keys: string[], options: SignedUrlOptions = {}): Promise<Map<string, string>> {
    const results = new Map<string, string>();
    
    // Process in parallel for performance
    const promises = keys.map(async (key) => {
      try {
        const url = await this.getSignedUrl(key, options);
        results.set(key, url);
      } catch (error) {
        console.error(`Failed to sign URL for ${key}:`, error);
        // Don't fail the entire batch for one missing file
      }
    });
    
    await Promise.all(promises);
    return results;
  }

  /**
   * Verify a signed URL is valid
   */
  async verifySignedUrl(url: string, secretKey: string): Promise<boolean> {
    try {
      const parsedUrl = new URL(url);
      const signature = parsedUrl.searchParams.get('X-Signature');
      const expires = parsedUrl.searchParams.get('X-Expires');
      
      if (!signature || !expires) {
        return false;
      }
      
      // Check expiration
      const expiryTime = parseInt(expires, 10);
      if (Date.now() > expiryTime) {
        return false;
      }
      
      // Extract key from URL
      const key = parsedUrl.pathname.substring(1); // Remove leading slash
      
      // Verify signature
      const expectedSignature = await this.generateSignature(key, expiryTime, secretKey);
      return signature === expectedSignature;
    } catch (error) {
      console.error('Failed to verify signed URL:', error);
      return false;
    }
  }

  /**
   * Generate HMAC signature for URL signing
   */
  private async generateSignature(
    key: string, 
    expiry: number,
    secretKey?: string
  ): Promise<string> {
    // Use a secret key from environment or generate one
    const secret = secretKey || 'nostrvine-r2-signing-key'; // Should be from env.R2_SIGNING_KEY
    
    const encoder = new TextEncoder();
    const data = encoder.encode(`${key}:${expiry}`);
    const keyData = encoder.encode(secret);
    
    const cryptoKey = await crypto.subtle.importKey(
      'raw',
      keyData,
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
    
    const signature = await crypto.subtle.sign('HMAC', cryptoKey, data);
    
    // Convert to base64url
    return btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '');
  }

  /**
   * Get direct R2 object (for internal use)
   */
  async getObject(key: string): Promise<R2ObjectBody | null> {
    try {
      return await this.r2Bucket.get(key);
    } catch (error) {
      console.error(`Failed to get object ${key}:`, error);
      return null;
    }
  }
}