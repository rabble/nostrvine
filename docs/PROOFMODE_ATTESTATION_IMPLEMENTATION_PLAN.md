Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This implementation plan may still be useful background, but it is not the active launch source of truth.

# ProofMode Attestation Implementation Plan

## Executive Summary

Implementation strategy for replacing mock attestation with real device attestation while maintaining open source transparency. The plan uses a dual-mode approach: mock attestation remains in the open source codebase, while CI/CD pipelines inject real attestation keys for official App Store/Play Store builds.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Open Source Repository                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ProofModeAttestationService                        │    │
│  │  └── MockAttestationProvider (default)              │    │
│  │  └── RealAttestationProvider (inactive)             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      CI/CD Pipeline                          │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  GitHub Actions / GitLab CI                         │    │
│  │  • Inject API keys from secrets                     │    │
│  │  • Switch to RealAttestationProvider                │    │
│  │  • Build official binaries                          │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Production Builds                         │
│  ┌──────────────────┐        ┌──────────────────┐          │
│  │   App Store      │        │   Play Store     │          │
│  │  (iOS App Attest)│        │ (Play Integrity) │          │
│  └──────────────────┘        └──────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Phases

### Phase 1: Environment Setup and Prerequisites
**Status: Ready to Start**

1. **Developer Account Configuration**
   - [ ] Verify Apple Developer account access
   - [ ] Enable App Attest capability in Xcode project
   - [ ] Configure Google Cloud project for Play Integrity
   - [ ] Set up Play Console integration

2. **Physical Device Inventory**
   - [ ] iOS devices: iPhone 11+ with iOS 14+
   - [ ] Android devices: Various manufacturers, API 21+
   - [ ] Document device test matrix

3. **Feature Flag Infrastructure**
   ```dart
   class ProofModeFeatures {
     static const attestationEnabled = 'proofmode_attestation_v1';
     static const screenDetectionEnabled = 'proofmode_screen_detection_v1';
   }
   ```

### Phase 2: iOS Native Implementation

**File: `ios/Runner/AttestationService.swift`**

```swift
import DeviceCheck

class AttestationService {
    private let service = DCAppAttestService.shared
    
    func generateAttestation(challenge: String) async throws -> String {
        guard service.isSupported else {
            throw AttestationError.notSupported
        }
        
        let keyId = try await service.generateKey()
        let challengeData = challenge.data(using: .utf8)!
        let attestation = try await service.attestKey(
            keyId, 
            clientDataHash: challengeData
        )
        
        return attestation.base64EncodedString()
    }
}
```

**Platform Channel Setup:**
- Channel name: `com.openvine/attestation`
- Methods: `generateAttestation`, `verifyAssertion`
- Error codes: `UNSUPPORTED`, `NETWORK_ERROR`, `INVALID_CHALLENGE`

### Phase 3: Android Native Implementation

**File: `android/app/src/main/kotlin/AttestationManager.kt`**

```kotlin
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest

class AttestationManager(private val context: Context) {
    private val integrityManager = IntegrityManagerFactory.create(context)
    
    fun generateIntegrityToken(nonce: String): Task<String> {
        val request = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .build()
            
        return integrityManager.requestIntegrityToken(request)
            .addOnSuccessListener { response ->
                response.token()
            }
    }
}
```

### Phase 4: Flutter Service Integration

**File: `lib/services/attestation/attestation_provider.dart`**

```dart
abstract class AttestationProvider {
  Future<DeviceAttestation> generateAttestation(String challenge);
  Future<bool> verifyAttestation(DeviceAttestation attestation);
}

class MockAttestationProvider implements AttestationProvider {
  // Existing mock implementation
}

class RealAttestationProvider implements AttestationProvider {
  final AppDeviceIntegrity _plugin = AppDeviceIntegrity();
  
  @override
  Future<DeviceAttestation> generateAttestation(String challenge) async {
    // Use app_device_integrity package
    final token = await _plugin.getAttestationServiceSupport(
      challengeString: challenge,
      gpc: Platform.isAndroid ? gcpProjectId : null,
    );
    
    return DeviceAttestation(
      token: token,
      platform: Platform.operatingSystem,
      // ... other fields
    );
  }
}
```

**Provider Selection:**
```dart
AttestationProvider getAttestationProvider() {
  const isProduction = bool.fromEnvironment('PRODUCTION_BUILD');
  return isProduction 
    ? RealAttestationProvider() 
    : MockAttestationProvider();
}
```

### Phase 5: Screen Refresh Detection Implementation

**File: `lib/services/screen_detection_service.dart`**

```dart
class ScreenRecordingDetector {
  static const refreshRates = [60, 120, 144]; // Hz
  
  Future<ScreenDetectionResult> analyzeFrames(
    List<FrameData> frames
  ) async {
    final results = await Future.wait([
      _detectRefreshArtifacts(frames),
      _detectPixelGrid(frames),
      _analyzeBlackLevels(frames),
      _detectScreenEdges(frames),
    ]);
    
    return ScreenDetectionResult(
      isLikelyScreen: results.any((r) => r.confidence > 0.7),
      confidence: results.map((r) => r.confidence).reduce(max),
      detectedArtifacts: results.where((r) => r.detected).toList(),
    );
  }
  
  Future<ArtifactResult> _detectRefreshArtifacts(
    List<FrameData> frames
  ) async {
    // FFT analysis for periodic patterns
    final fft = FFT(frames.map((f) => f.luminance).toList());
    final spectrum = fft.compute();
    
    for (final rate in refreshRates) {
      if (spectrum.hasPeakAt(rate)) {
        return ArtifactResult(
          type: 'refresh_rate',
          confidence: spectrum.peakStrength(rate),
          detected: true,
        );
      }
    }
    
    return ArtifactResult(detected: false);
  }
}
```

### Phase 6: Backend Verification Service

**File: `backend/src/attestation-verify.ts`**

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    
    if (url.pathname === '/verify/ios') {
      return handleIOSVerification(request, env);
    }
    
    if (url.pathname === '/verify/android') {
      return handleAndroidVerification(request, env);
    }
    
    return new Response('Not Found', { status: 404 });
  }
};

async function handleIOSVerification(
  request: Request, 
  env: Env
): Promise<Response> {
  const { token, challenge } = await request.json();
  
  // Verify with Apple servers
  const response = await fetch(
    'https://api.devicecheck.apple.com/v1/validate',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.APPLE_JWT}`,
      },
      body: JSON.stringify({ 
        attestation: token, 
        challenge 
      }),
    }
  );
  
  const isValid = response.ok;
  
  // Cache result
  await env.ATTESTATION_CACHE.put(
    token, 
    JSON.stringify({ isValid, timestamp: Date.now() }),
    { expirationTtl: 3600 }
  );
  
  return Response.json({
    isValid,
    attestationType: 'app_attest',
    confidence: isValid ? 0.95 : 0,
  });
}
```

### Phase 7: UI Verification Badges

**File: `lib/widgets/verification_badge.dart`**

```dart
class VerificationBadge extends StatelessWidget {
  final VerificationStatus status;
  final VoidCallback? onTap;
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _showProofDetails(context),
      child: Container(
        padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getIcon(),
              size: 16,
              color: _getIconColor(),
            ),
            if (status == VerificationStatus.verified)
              Text(
                ' Verified',
                style: TextStyle(fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
  
  IconData _getIcon() {
    switch (status) {
      case VerificationStatus.verified:
        return Icons.check_circle;
      case VerificationStatus.suspicious:
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }
}
```

**Proof Details Sheet:**
```dart
class ProofDetailsSheet extends StatelessWidget {
  final ProofModeData proofData;
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verification Details', 
            style: Theme.of(context).textTheme.headline6),
          SizedBox(height: 16),
          
          _buildDetailRow('App Build', 
            proofData.isOfficialBuild 
              ? 'Official App Store' 
              : 'Community Build'),
          
          _buildDetailRow('Attestation', 
            proofData.attestationType ?? 'None'),
          
          _buildDetailRow('Camera Capture', 
            proofData.isCameraCapture ? 'Verified' : 'Unknown'),
          
          _buildDetailRow('Human Movement', 
            proofData.humanMovementDetected ? 'Detected' : 'Not detected'),
          
          _buildDetailRow('Screen Recording', 
            proofData.screenArtifacts ? 'Possible' : 'Unlikely'),
          
          _buildDetailRow('Timestamp', 
            proofData.timestamp.toIso8601String()),
          
          if (proofData.signature != null)
            _buildDetailRow('Signature', 
              'Valid PGP signature'),
          
          SizedBox(height: 16),
          
          TextButton(
            onPressed: () => _showTechnicalDetails(context),
            child: Text('View Technical Details'),
          ),
        ],
      ),
    );
  }
}
```

### Phase 8: Production Rollout & Monitoring

**CI/CD Configuration: `.github/workflows/release.yml`**

```yaml
name: Release Build

on:
  push:
    tags:
      - 'v*'

jobs:
  build-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Inject Attestation Keys
        env:
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
          APP_ATTEST_KEY: ${{ secrets.APP_ATTEST_KEY }}
        run: |
          echo "const String appAttestKey = '$APP_ATTEST_KEY';" \
            > lib/config/attestation_keys.dart
          
      - name: Build iOS Release
        run: |
          flutter build ios --release \
            --dart-define=PRODUCTION_BUILD=true
            
  build-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Inject Play Integrity Config
        env:
          GCP_PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
          PLAY_INTEGRITY_KEY: ${{ secrets.PLAY_INTEGRITY_KEY }}
        run: |
          echo "const int gcpProjectId = $GCP_PROJECT_ID;" \
            >> lib/config/attestation_keys.dart
```

**Feature Flag Configuration:**
```dart
class FeatureRollout {
  static const rolloutPercentages = {
    'proofmode_attestation_v1': 5,      // 5% initial rollout
    'proofmode_screen_detection_v1': 2, // 2% for screen detection
  };
  
  static bool isEnabled(String feature) {
    final percentage = rolloutPercentages[feature] ?? 0;
    final userId = getUserId();
    final hash = userId.hashCode;
    return (hash % 100) < percentage;
  }
}
```

**Monitoring Dashboard Metrics:**
```dart
class AttestationMetrics {
  static void track(String event, Map<String, dynamic> properties) {
    analytics.track(event, properties);
  }
  
  static void trackAttestationResult(bool success, String platform) {
    track('attestation_result', {
      'success': success,
      'platform': platform,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  static void trackScreenDetection(bool detected, double confidence) {
    track('screen_detection', {
      'detected': detected,
      'confidence': confidence,
    });
  }
  
  static void trackVerificationLatency(Duration latency) {
    track('verification_latency', {
      'milliseconds': latency.inMilliseconds,
    });
  }
}
```

## Rollback Procedures

1. **Feature Flag Disable**
   ```dart
   // Emergency disable via remote config
   RemoteConfig.setOverride('proofmode_attestation_v1', 0);
   ```

2. **Fallback to Mock**
   ```dart
   // Automatic fallback on error
   try {
     return await RealAttestationProvider().generateAttestation(challenge);
   } catch (e) {
     Log.error('Attestation failed, falling back to mock', e);
     return await MockAttestationProvider().generateAttestation(challenge);
   }
   ```

## Testing Strategy

### Device Test Matrix
```
iOS Devices:
- iPhone 11 (iOS 14.0) - Minimum supported
- iPhone 13 (iOS 15.x) - Mid-range test
- iPhone 15 (iOS 17.x) - Latest version

Android Devices:
- Pixel 4a (Android 11) - Reference device
- Samsung Galaxy S21 (Android 12) - Popular manufacturer
- OnePlus 9 (Android 13) - Alternative manufacturer
- Xiaomi Redmi Note (Android 10) - Budget device
```

### Test Scenarios
1. **Attestation Success Path**
   - Official build generates valid token
   - Backend verifies successfully
   - UI shows verification badge

2. **Attestation Failure Handling**
   - Unsupported device gracefully falls back
   - Network errors handled with retry
   - Invalid tokens logged but don't crash

3. **Screen Detection Validation**
   - Test with actual screen recordings
   - Verify tripod recordings pass
   - Check false positive rate < 1%

## Success Metrics

Target metrics for production release:
- Attestation success rate: > 95% on supported devices
- Verification latency: < 500ms P95
- Screen detection accuracy: > 90% true positive, < 1% false positive
- User engagement with badges: > 30% click-through on "View Proof"

## Key Rotation Schedule

Quarterly rotation process:
1. Generate new attestation keys (Month 3, Week 2)
2. Update CI/CD secrets (Month 3, Week 3)
3. Deploy with overlap period (Month 3, Week 4)
4. Deprecate old keys (Month 1, Week 2 of next quarter)

## Documentation Updates

Files to update:
- `README.md` - Note attestation in official builds
- `CONTRIBUTING.md` - Explain mock vs real attestation
- `docs/ATTESTATION_ARCHITECTURE.md` - Technical details
- `docs/VERIFICATION_API.md` - Backend endpoints

## Risk Mitigation

1. **CI/CD Secret Exposure**
   - Use GitHub secret scanning
   - Rotate keys immediately if exposed
   - Audit access logs monthly

2. **Apple/Google API Changes**
   - Monitor deprecation notices
   - Maintain abstraction layer
   - Test beta OS versions

3. **Performance Impact**
   - Monitor frame rate during recording
   - Cache attestation results
   - Optimize screen detection algorithms

## Next Steps

1. Review and approve plan with team
2. Set up developer accounts and API access
3. Create feature branch for implementation
4. Begin with Phase 1: Environment Setup
5. Weekly progress reviews during implementation

---

*This plan provides a comprehensive approach to implementing real device attestation while maintaining OpenVine's open source nature. The dual-mode architecture ensures transparency while enabling trust signals for official builds.*
