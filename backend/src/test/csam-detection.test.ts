// ABOUTME: Tests for CSAM detection and content safety scanning
// ABOUTME: Validates content safety measures and proper blocking of harmful content

import { describe, it, expect, beforeEach } from 'vitest';
import { 
  ContentSafetyScanner, 
  reportCSAMToAuthorities,
  ContentSafetyResult,
  CSAMDetectionResult 
} from '../handlers/csam-detection';
import { FileMetadata } from '../types/nip96';

describe('Content Safety Scanner', () => {
  let scanner: ContentSafetyScanner;
  
  beforeEach(() => {
    scanner = new ContentSafetyScanner();
  });

  describe('Basic Content Scanning', () => {
    it('should allow safe content', async () => {
      const safeImageData = new TextEncoder().encode('safe image content').buffer;
      const metadata: FileMetadata = {
        id: 'test-safe-001',
        filename: 'family-photo.jpg',
        content_type: 'image/jpeg',
        size: 102400,
        sha256: 'a1b2c3d4e5f67890123456789012345678901234567890123456789012345678',
        uploaded_at: Date.now(),
        url: 'https://example.com/safe-image.jpg'
      };

      const result = await scanner.scanContent(safeImageData, metadata);

      expect(result.isSafe).toBe(true);
      expect(result.overallRisk).toBe('low');
      expect(result.recommendedAction).toBe('allow');
      expect(result.violations.csam).toBeDefined();
      expect(result.violations.csam!.isCSAM).toBe(false);
    });

    it('should detect spam patterns', async () => {
      const spamData = new TextEncoder().encode('spam content').buffer;
      const metadata: FileMetadata = {
        id: 'test-spam-001',
        filename: 'free-money-click-here.jpg',
        content_type: 'image/jpeg',
        size: 51200,
        sha256: 'b1c2d3e4f5678901234567890123456789012345678901234567890123456789',
        uploaded_at: Date.now(),
        url: 'https://example.com/spam-image.jpg'
      };

      const result = await scanner.scanContent(spamData, metadata);

      expect(result.violations.spam).toBe(true);
      expect(result.overallRisk).toBe('medium');
      expect(result.recommendedAction).toBe('flag');
    });

    it('should handle scanning errors gracefully', async () => {
      // Simulate a corrupted file that causes scanning errors
      const corruptedData = new ArrayBuffer(0); // Empty buffer
      const metadata: FileMetadata = {
        id: 'test-error-001',
        filename: 'corrupted.jpg',
        content_type: 'image/jpeg',
        size: 0,
        sha256: 'invalid-hash',
        uploaded_at: Date.now(),
        url: 'https://example.com/corrupted.jpg'
      };

      const result = await scanner.scanContent(corruptedData, metadata);

      // Scanner should fail-safe and block suspicious content
      expect(result.isSafe).toBe(false);
      expect(result.recommendedAction).toBe('block');
      // Zero-size files should trigger file_analysis detection method
      expect(result.violations.csam?.detectionMethods).toContain('file_analysis');
    });
  });

  describe('CSAM Detection', () => {
    it('should properly structure CSAM detection results', async () => {
      const testData = new TextEncoder().encode('test content').buffer;
      const metadata: FileMetadata = {
        id: 'test-csam-001',
        filename: 'test.jpg',
        content_type: 'image/jpeg',
        size: 102400,
        sha256: 'c1d2e3f4567890123456789012345678901234567890123456789012345678901',
        uploaded_at: Date.now(),
        url: 'https://example.com/test.jpg'
      };

      const result = await scanner.scanContent(testData, metadata);

      expect(result.violations.csam).toBeDefined();
      expect(result.violations.csam).toHaveProperty('isCSAM');
      expect(result.violations.csam).toHaveProperty('confidence');
      expect(result.violations.csam).toHaveProperty('reason');
      expect(result.violations.csam).toHaveProperty('action');
      expect(result.violations.csam).toHaveProperty('detectionMethods');
      
      expect(Array.isArray(result.violations.csam!.detectionMethods)).toBe(true);
      expect(['allow', 'block', 'review']).toContain(result.violations.csam!.action);
    });

    it('should use multiple detection methods', async () => {
      const testData = new TextEncoder().encode('test image data').buffer;
      const metadata: FileMetadata = {
        id: 'test-methods-001',
        filename: 'test-image.jpg',
        content_type: 'image/jpeg',
        size: 512000,
        sha256: 'd1e2f3456789012345678901234567890123456789012345678901234567890123',
        uploaded_at: Date.now(),
        url: 'https://example.com/test-image.jpg'
      };

      const result = await scanner.scanContent(testData, metadata);

      const methods = result.violations.csam!.detectionMethods;
      expect(methods.length).toBeGreaterThan(0);
      
      // Should include various detection methods
      const expectedMethods = ['hash_database', 'ml_image_classification', 'metadata_analysis', 'file_analysis'];
      const hasValidMethods = methods.some(method => expectedMethods.includes(method));
      expect(hasValidMethods).toBe(true);
    });
  });

  describe('Content Type Handling', () => {
    it('should handle video content differently than images', async () => {
      const videoData = new TextEncoder().encode('video content data').buffer;
      const videoMetadata: FileMetadata = {
        id: 'test-video-001',
        filename: 'test-video.mp4',
        content_type: 'video/mp4',
        size: 5242880, // 5MB
        sha256: 'e1f2345678901234567890123456789012345678901234567890123456789012',
        uploaded_at: Date.now(),
        url: 'https://example.com/test-video.mp4',
        duration: 6.5
      };

      const result = await scanner.scanContent(videoData, videoMetadata);

      expect(result).toBeDefined();
      expect(result.violations.csam).toBeDefined();
      // Video processing should not fail
      expect(result.violations.csam!.detectionMethods).not.toContain('error_fallback');
    });

    it('should handle large video files appropriately', async () => {
      const largeVideoData = new ArrayBuffer(3600 * 1024); // Large video simulation
      const metadata: FileMetadata = {
        id: 'test-large-video-001',
        filename: 'long-video.mp4',
        content_type: 'video/mp4',
        size: largeVideoData.byteLength,
        sha256: 'f123456789012345678901234567890123456789012345678901234567890123',
        uploaded_at: Date.now(),
        url: 'https://example.com/long-video.mp4',
        duration: 3600 // 1 hour video
      };

      const result = await scanner.scanContent(largeVideoData, metadata);

      // Long videos should be flagged as suspicious for vine content
      expect(result.overallRisk).not.toBe('low');
      expect(result.violations.csam?.detectionMethods).toContain('file_analysis');
      expect(result.violations.csam?.isCSAM).toBe(true);
    });
  });

  describe('Risk Assessment', () => {
    it('should calculate risk levels correctly', async () => {
      const testData = new TextEncoder().encode('test').buffer;
      const safeMetadata: FileMetadata = {
        id: 'test-risk-001',
        filename: 'safe-content.jpg',
        content_type: 'image/jpeg',
        size: 102400,
        sha256: 'safe123456789012345678901234567890123456789012345678901234567890',
        uploaded_at: Date.now(),
        url: 'https://example.com/safe.jpg'
      };

      const result = await scanner.scanContent(testData, safeMetadata);

      expect(['low', 'medium', 'high', 'critical']).toContain(result.overallRisk);
      expect(['allow', 'flag', 'block', 'immediate_block']).toContain(result.recommendedAction);
    });
  });
});

describe('CSAM Reporting', () => {
  const mockEnv = {
    CLOUDFLARE_ACCOUNT_ID: 'test-account',
    CLOUDFLARE_STREAM_TOKEN: 'test-token'
  } as unknown as Env;

  it('should handle CSAM reporting without errors', async () => {
    const metadata: FileMetadata = {
      id: 'test-report-001',
      filename: 'reported-content.jpg',
      content_type: 'image/jpeg',
      size: 102400,
      sha256: 'report123456789012345678901234567890123456789012345678901234567890',
      uploaded_at: Date.now(),
      url: 'https://example.com/reported.jpg'
    };

    const detectionResult: CSAMDetectionResult = {
      isCSAM: true,
      confidence: 0.95,
      reason: 'High confidence CSAM detection',
      action: 'block',
      detectionMethods: ['hash_database', 'ml_image_classification']
    };

    // Should not throw errors
    await expect(
      reportCSAMToAuthorities(metadata, detectionResult, mockEnv)
    ).resolves.not.toThrow();
  });

  it('should handle reporting failures gracefully', async () => {
    const metadata: FileMetadata = {
      id: 'test-report-error-001',
      filename: 'error-test.jpg',
      content_type: 'image/jpeg',
      size: 102400,
      sha256: 'error123456789012345678901234567890123456789012345678901234567890',
      uploaded_at: Date.now(),
      url: 'https://example.com/error.jpg'
    };

    const detectionResult: CSAMDetectionResult = {
      isCSAM: true,
      confidence: 0.99,
      reason: 'Critical CSAM detection',
      action: 'block',
      detectionMethods: ['hash_database']
    };

    // Even if reporting fails, it should not throw
    await expect(
      reportCSAMToAuthorities(metadata, detectionResult, mockEnv)
    ).resolves.not.toThrow();
  });
});

describe('Content Safety Integration', () => {
  it('should work with real-world file patterns', async () => {
    const scanner = new ContentSafetyScanner();
    
    // Test with realistic metadata patterns
    const testCases = [
      {
        filename: 'vacation-photo.jpg',
        contentType: 'image/jpeg',
        size: 2048000,
        expectedSafe: true
      },
      {
        filename: 'family-video.mp4', 
        contentType: 'video/mp4',
        size: 15728640, // 15MB
        expectedSafe: true
      },
      {
        filename: 'suspicious-teen-content.jpg',
        contentType: 'image/jpeg',
        size: 1024000,
        expectedSafe: false // Should trigger metadata warnings
      }
    ];

    for (const testCase of testCases) {
      const testData = new ArrayBuffer(1024);
      const metadata: FileMetadata = {
        id: `test-${Date.now()}`,
        filename: testCase.filename,
        content_type: testCase.contentType,
        size: testCase.size,
        sha256: `test${Date.now()}${'0'.repeat(58)}`,
        uploaded_at: Date.now(),
        url: `https://example.com/${testCase.filename}`
      };

      const result = await scanner.scanContent(testData, metadata);
      
      if (testCase.expectedSafe) {
        expect(result.overallRisk).not.toBe('critical');
        expect(result.recommendedAction).not.toBe('immediate_block');
      } else {
        // Suspicious content should at least be flagged
        expect(result.overallRisk).not.toBe('low');
      }
    }
  });

  it('should provide consistent results for identical content', async () => {
    const scanner = new ContentSafetyScanner();
    const testData = new TextEncoder().encode('consistent test content').buffer;
    const metadata: FileMetadata = {
      id: 'test-consistent-001',
      filename: 'consistent-test.jpg',
      content_type: 'image/jpeg',
      size: testData.byteLength,
      sha256: 'consistent123456789012345678901234567890123456789012345678901234567',
      uploaded_at: Date.now(),
      url: 'https://example.com/consistent.jpg'
    };

    const result1 = await scanner.scanContent(testData, metadata);
    const result2 = await scanner.scanContent(testData, metadata);

    expect(result1.isSafe).toBe(result2.isSafe);
    expect(result1.overallRisk).toBe(result2.overallRisk);
    expect(result1.recommendedAction).toBe(result2.recommendedAction);
    expect(result1.violations.csam?.isCSAM).toBe(result2.violations.csam?.isCSAM);
  });
});