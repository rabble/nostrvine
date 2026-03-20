Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# ProofMode Production Integration Requirements

## Overview

This document outlines the technical requirements and implementation steps needed to move OpenVine's ProofMode from the current mock implementation to a production-ready system with real camera integration, hardware attestation, and robust cryptography.

## Current Implementation Status

### ✅ Completed (Mock/Foundation)
- Feature flag system with progressive rollout
- Session management and proof manifest generation
- Human activity detection algorithms
- Camera service integration layer
- Comprehensive test suite
- JSON serialization and data structures

### 🚧 Needs Production Implementation
- Real PGP cryptography (currently mock implementation)
- Actual device attestation APIs (iOS App Attest, Android Play Integrity)
- Real-time frame capture and hashing
- Platform-specific sensor data collection
- Hardware-backed key storage validation
- Production verification services

## Production Implementation Roadmap

### Phase 1: Cryptography Infrastructure (2-3 weeks)

#### 1.1 Real PGP Implementation

**Current State**: Mock implementation using simple SHA256 hashing
**Required**: Production PGP key generation, signing, and verification

**Implementation Options**:

1. **Option A: dart_pg Package** (Recommended)
   ```yaml
   dependencies:
     dart_pg: ^0.4.0  # Pure Dart PGP implementation
   ```
   - ✅ Pure Dart, no platform channels needed
   - ✅ Cross-platform compatibility
   - ✅ Actively maintained
   - ❌ May have performance limitations for large operations

2. **Option B: Platform Channels with Native Libraries**
   ```dart
   // iOS: Use CryptoKit + OpenPGP.swift
   // Android: Use Bouncy Castle PGP
   ```
   - ✅ Better performance
   - ✅ Hardware acceleration available
   - ❌ More complex implementation
   - ❌ Platform-specific code required

**Implementation Steps**:
1. Replace `ProofModeKeyService._generateSimpleKeyPair()` with real PGP key generation
2. Replace `_signWithPrivateKey()` with actual PGP signing
3. Replace `_verifyWithPublicKey()` with real PGP verification
4. Add key format validation and error handling
5. Update secure storage to handle proper PGP key formats

**Code Changes Required**:
```dart
// Replace in proofmode_key_service.dart
Future<ProofModeKeyPair> generateKeyPair() async {
  final keyPair = await PgpKeyGenerator.generate(
    name: 'OpenVine ProofMode',
    email: 'device@openvine.co',
    keySize: 4096,
  );
  
  return ProofModeKeyPair(
    publicKey: keyPair.publicKey.armor(),
    privateKey: keyPair.privateKey.armor(),
    fingerprint: keyPair.publicKey.fingerprint,
    createdAt: DateTime.now(),
  );
}
```

#### 1.2 Hardware-Backed Key Storage

**Current State**: Using FlutterSecureStorage (software-based)
**Required**: Verify hardware-backed storage on supported devices

**Implementation Steps**:
1. Add hardware keystore validation for Android
2. Add Secure Enclave validation for iOS
3. Implement graceful fallback for unsupported devices
4. Add hardware attestation for stored keys

### Phase 2: Device Attestation Implementation (2-3 weeks)

#### 2.1 iOS App Attest Integration

**Current State**: Mock implementation returning test tokens
**Required**: Real iOS App Attest API integration

**Prerequisites**:
- iOS 14+ target deployment
- Valid Apple Developer account
- App Store Connect configuration

**Implementation Steps**:
1. Enable App Attest capability in Xcode project
2. Implement native Swift bridge for App Attest
3. Handle App Attest key generation and attestation
4. Implement assertion generation for ongoing validation

**Code Implementation**:
```swift
// iOS native code (Platform Channel)
import DeviceCheck

class AppAttestService {
    func generateAttestation(challenge: String) async throws -> String {
        let service = DCAppAttestService.shared
        
        guard service.isSupported else {
            throw AttestationError.notSupported
        }
        
        let keyId = try await service.generateKey()
        let challengeData = challenge.data(using: .utf8)!
        let attestation = try await service.attestKey(keyId, clientDataHash: challengeData)
        
        return attestation.base64EncodedString()
    }
}
```

**Dart Integration**:
```dart
// Replace in proofmode_attestation_service.dart
Future<DeviceAttestation> _generateiOSAttestation(String challenge, DeviceInfo deviceInfo) async {
  try {
    final attestationToken = await platform.invokeMethod('generateAttestation', {
      'challenge': challenge,
    });
    
    return DeviceAttestation(
      token: attestationToken,
      platform: 'iOS',
      deviceId: deviceInfo.deviceId,
      isHardwareBacked: true,
      createdAt: DateTime.now(),
      challenge: challenge,
    );
  } catch (e) {
    throw AttestationException('iOS App Attest failed: $e');
  }
}
```

#### 2.2 Android Play Integrity Integration

**Current State**: Mock implementation
**Required**: Google Play Integrity API integration

**Prerequisites**:
- Google Play Console project setup
- Play Integrity API enabled
- Valid Google Cloud project

**Implementation Steps**:
1. Add Play Integrity API dependency
2. Configure Google Cloud project credentials
3. Implement integrity token generation
4. Handle device and app integrity validation

**Code Implementation**:
```kotlin
// Android native code
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest

class PlayIntegrityService {
    fun generateIntegrityToken(nonce: String): Task<String> {
        val integrityManager = IntegrityManagerFactory.create(context)
        
        val integrityTokenRequest = IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .build()
            
        return integrityManager.requestIntegrityToken(integrityTokenRequest)
            .addOnSuccessListener { response ->
                return@addOnSuccessListener response.token()
            }
    }
}
```

### Phase 3: Real-Time Camera Integration (3-4 weeks)

#### 3.1 Frame Capture and Hashing

**Current State**: Mock frame hash generation
**Required**: Real-time frame extraction and SHA256 hashing

**Implementation Options**:

1. **Option A: Camera Controller Frame Sampling**
   ```dart
   // Sample frames during recording
   Timer.periodic(Duration(milliseconds: 100), (timer) {
     if (isRecording) {
       _captureCurrentFrame();
     }
   });
   ```

2. **Option B: Platform-Specific Frame Access**
   ```dart
   // Use platform channels to access raw camera data
   ```

**Implementation Steps**:
1. Modify camera service to expose frame data
2. Implement background isolate for frame processing
3. Add frame sampling rate configuration
4. Optimize performance to avoid recording lag

**Code Changes**:
```dart
// Add to camera_service.dart
Stream<Uint8List> get frameStream async* {
  while (isRecording) {
    final frame = await _controller?.captureFrame();
    if (frame != null) {
      yield frame;
    }
    await Future.delayed(Duration(milliseconds: 100));
  }
}

// Update proofmode_session_service.dart
void _startFrameCapture() {
  _frameSubscription = _cameraService.frameStream.listen((frameData) {
    _processFrameInIsolate(frameData);
  });
}
```

#### 3.2 Sensor Data Collection

**Current State**: Mock sensor data generation
**Required**: Real device sensor integration

**Required Sensors**:
- Accelerometer (device movement)
- Gyroscope (rotation detection)
- Magnetometer (orientation)
- Light sensor (environmental changes)

**Implementation**:
```dart
dependencies:
  sensors_plus: ^4.0.2
  
// Implementation
class SensorDataCollector {
  Future<Map<String, dynamic>> collectSensorSnapshot() async {
    final accelerometer = await accelerometerEvents.first;
    final gyroscope = await gyroscopeEvents.first;
    final magnetometer = await magnetometerEvents.first;
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'accelerometer': {
        'x': accelerometer.x,
        'y': accelerometer.y,
        'z': accelerometer.z,
      },
      'gyroscope': {
        'x': gyroscope.x,
        'y': gyroscope.y,
        'z': gyroscope.z,
      },
      // ... other sensors
    };
  }
}
```

### Phase 4: Production Verification Services (2-3 weeks)

#### 4.1 Cloudflare Workers Verification API

**Implementation Steps**:
1. Create Cloudflare Workers for proof verification
2. Implement PGP signature validation
3. Add device attestation verification
4. Create verification result API

**API Structure**:
```typescript
// Cloudflare Workers
export default {
  async fetch(request: Request): Promise<Response> {
    const proofManifest = await request.json();
    
    const verification = await verifyProofManifest(proofManifest);
    
    return new Response(JSON.stringify(verification), {
      headers: { 'Content-Type': 'application/json' },
    });
  }
};

async function verifyProofManifest(manifest: ProofManifest): Promise<VerificationResult> {
  // 1. Verify PGP signature
  const signatureValid = await verifyPGPSignature(manifest);
  
  // 2. Verify device attestation
  const attestationValid = await verifyDeviceAttestation(manifest.deviceAttestation);
  
  // 3. Analyze human activity patterns
  const humanActivityAnalysis = analyzeHumanActivity(manifest.interactions);
  
  return {
    isValid: signatureValid && attestationValid,
    proofLevel: determineProofLevel(manifest),
    humanLikely: humanActivityAnalysis.isHumanLikely,
    confidenceScore: humanActivityAnalysis.confidenceScore,
  };
}
```

## Platform-Specific Requirements

### iOS Requirements

**Minimum Versions**:
- iOS 14.0+ (for App Attest)
- Xcode 14+
- Swift 5.7+

**Capabilities to Enable**:
```xml
<!-- ios/Runner/Runner.entitlements -->
<key>com.apple.developer.devicecheck.appattest-environment</key>
<string>development</string> <!-- or 'production' -->
```

**Info.plist Additions**:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera access required for ProofMode video verification</string>
```

### Android Requirements

**Minimum Versions**:
- Android API 21+ (Android 5.0)
- Compile SDK 34
- Gradle 8.0+

**Dependencies**:
```gradle
dependencies {
    implementation 'com.google.android.play:integrity:1.3.0'
    implementation 'org.bouncycastle:bcprov-jdk15on:1.70'
}
```

**Permissions**:
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## Performance Optimization Requirements

### Memory Management
- Implement frame processing in background isolates
- Use memory pools for frame buffer management
- Implement LRU cache for proof data
- Monitor memory usage during long recording sessions

### CPU Optimization
- Use platform-specific optimized cryptography
- Implement adaptive frame sampling based on device performance
- Use hardware acceleration where available
- Profile and optimize human activity detection algorithms

### Battery Optimization
- Implement efficient sensor polling
- Use low-power modes during recording pauses
- Optimize cryptographic operations
- Monitor and report battery impact

## Security Hardening Requirements

### Key Protection
- Verify hardware-backed key storage
- Implement key rotation policies
- Add key backup and recovery mechanisms
- Monitor for key compromise

### Anti-Tampering
- Implement app integrity validation
- Add runtime application self-protection (RASP)
- Detect debugging and reverse engineering tools
- Implement certificate pinning for API calls

### Privacy Protection
- Implement data minimization
- Add user consent mechanisms
- Provide data deletion capabilities
- Ensure GDPR/CCPA compliance

## Testing and Validation Requirements

### Automated Testing
- Unit tests for all production implementations
- Integration tests with real camera hardware
- Performance tests on various device configurations
- Security penetration testing

### Manual Testing
- Device compatibility testing (50+ device models)
- User acceptance testing with content creators
- Accessibility testing with assistive technologies
- Network condition testing (offline, poor connectivity)

## Deployment and Monitoring Requirements

### Feature Flag Strategy
```dart
// Progressive rollout plan
final rolloutPhases = {
  'proofmode_crypto_v1': 5,      // 5% rollout
  'proofmode_attestation_v1': 2, // 2% rollout
  'proofmode_camera_v1': 1,      // 1% rollout
  'proofmode_production_v1': 0,  // 0% rollout initially
};
```

### Monitoring and Analytics
- Real-time performance metrics
- False positive/negative tracking
- User adoption and engagement metrics
- Error rate and crash monitoring

### Support Infrastructure
- User appeals process for false positives
- Technical support documentation
- Developer debugging tools
- Community feedback channels

## Estimated Implementation Timeline

| Phase | Duration | Dependencies | Risk Level |
|-------|----------|--------------|------------|
| Phase 1: Cryptography | 2-3 weeks | dart_pg evaluation | Medium |
| Phase 2: Device Attestation | 2-3 weeks | Apple/Google approval | High |
| Phase 3: Camera Integration | 3-4 weeks | Frame access APIs | High |
| Phase 4: Verification Services | 2-3 weeks | Cloudflare Workers | Low |
| **Total** | **9-13 weeks** | | |

## Success Criteria

### Technical Metrics
- [ ] PGP operations complete in <500ms
- [ ] Device attestation success rate >90%
- [ ] Frame capture adds <100ms to recording start
- [ ] Battery impact <5% additional drain
- [ ] Memory usage <50MB additional

### Quality Metrics
- [ ] Bot detection accuracy >95%
- [ ] Human recognition accuracy >98%
- [ ] False positive rate <1%
- [ ] Creative content support >95%
- [ ] Cross-platform consistency >95%

### Production Readiness
- [ ] All unit tests passing
- [ ] Integration tests with real hardware
- [ ] Security audit completed
- [ ] Performance benchmarks met
- [ ] Documentation completed

This production roadmap provides a clear path from the current mock implementation to a fully functional ProofMode system that can reliably distinguish human-captured content from automated content while maintaining excellent performance and user experience.