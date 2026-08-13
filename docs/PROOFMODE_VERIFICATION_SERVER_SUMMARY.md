# ProofMode Verification Server - Quick Reference

## TL;DR for Implementation Team

Build a Cloudflare Workers API at `/verify` endpoint that validates ProofManifests and returns trust levels.

**Tech Stack**: Cloudflare Workers + OpenPGP.js + R2 Storage
**Target Response Time**: <500ms
**Full Requirements**: See `PROOFMODE_VERIFICATION_SERVER_REQUIREMENTS.md`

---

## Core Verification Steps

### 1. PGP Signature Verification (40% weight)
```typescript
// Verify manifest hasn't been tampered with
const pgpValid = await openpgp.verify({
  message: signedMessage,
  verificationKeys: publicKey
});
```

**Checks**:
- ✅ Signature cryptographically valid
- ✅ Fingerprint matches public key
- ✅ Signed data matches manifest content

---

### 2. Device Attestation Validation (30% weight)

**iOS App Attest**:
```typescript
// Verify hardware-backed iOS attestation
const isValid = await validateAppleAttestation(token, challenge);
```

**Android Play Integrity**:
```typescript
// Verify Google Play Integrity JWT
const verdict = await verifyPlayIntegrityJWT(token, challenge);
// Check verdict: MEETS_DEVICE_INTEGRITY or MEETS_STRONG_INTEGRITY
```

**Checks**:
- ✅ Token signature valid (Apple/Google keys)
- ✅ Challenge nonce matches manifest
- ✅ Device integrity verdict acceptable
- ✅ Token timestamp recent (<1 hour)

---

### 3. Human Activity Analysis (30% weight)

**Sensor Pattern Analysis**:
```typescript
// Detect natural hand movement vs bot patterns
const sensorScore = analyzeSensorPatterns(segments);
// Look for: accelerometer variance, gyroscope variation, natural jitter
```

**Timing Pattern Analysis**:
```typescript
// Detect human timing irregularities
const timingScore = analyzeTimingPatterns(manifest);
// Look for: duration variance, pause irregularity, millisecond precision
```

**Human Indicators**:
- ✅ Accelerometer variance > 0.01 m/s² (hand shake)
- ✅ Gyroscope rotation detected
- ✅ Recording duration variance (not exactly 6.000s)
- ✅ Irregular pause timing
- ✅ Millisecond-precision timestamps

**Bot Indicators**:
- ❌ All sensor values zero
- ❌ Perfectly static readings
- ❌ Exact timing (6000ms every time)
- ❌ No pauses or perfectly timed pauses

---

## Verification Levels

**verified_mobile** (Highest Trust):
- ✅ Hardware-backed attestation (iOS App Attest or Android Play Integrity)
- ✅ Valid PGP signature
- ✅ High human activity confidence (>0.8)
- Use for: Official content, legal evidence, journalism

**verified_web** (Medium-High Trust):
- ✅ Valid PGP signature
- ✅ Web-based attestation (no hardware backing)
- Use for: User-generated content from web builds

**basic_proof** (Basic Trust):
- ✅ Valid PGP signature only
- ❌ No attestation OR failed human activity check
- Use for: Questionable content, low-confidence scenarios

**unverified** (No Trust):
- ❌ Invalid signature or attestation
- Use for: Flagged/suspicious content

---

## Confidence Score Calculation

```typescript
let score = 0;

// Base cryptographic verification (40%)
if (pgpValid) score += 0.40;

// Device attestation (30%)
if (attestationValid && hardwareBacked) score += 0.30;
else if (attestationValid) score += 0.15;

// Human activity patterns (30%)
const humanConfidence = (sensorScore + timingScore) / 2;
score += humanConfidence * 0.30;

return Math.min(1.0, score); // Clamp to [0, 1]
```

---

## API Request/Response

**POST /verify**

**Request**:
```json
{
  "proofManifest": { ...full manifest... },
  "publicKey": "-----BEGIN PGP PUBLIC KEY BLOCK-----\n...\n-----END PGP PUBLIC KEY BLOCK-----"
}
```

**Response** (200 OK):
```json
{
  "isValid": true,
  "verificationLevel": "verified_mobile",
  "verificationDetails": {
    "pgpSignatureValid": true,
    "deviceAttestationValid": true,
    "deviceAttestationType": "app_attest",
    "isHardwareBacked": true,
    "humanActivityConfidence": 0.92,
    "humanLikely": true
  },
  "confidenceScore": 0.95,
  "warnings": [],
  "errors": []
}
```

**Response** (422 Unprocessable Entity - Verification Failed):
```json
{
  "isValid": false,
  "verificationLevel": "unverified",
  "verificationDetails": {
    "pgpSignatureValid": false,
    "deviceAttestationValid": true,
    "humanActivityConfidence": 0.45
  },
  "errors": [
    "PGP signature verification failed: Invalid signature"
  ]
}
```

---

## Performance Optimization

**R2 Caching Strategy**:
```typescript
// Check cache first
const cached = await R2.get(`verification/${sessionId}`);
if (cached && age < 24h) {
  return cached; // <100ms response
}

// Full verification if cache miss
const result = await runFullVerification(manifest);

// Cache result for 7 days
await R2.put(`verification/${sessionId}`, result, { ttl: 7days });

return result; // <500ms response
```

**Target Metrics**:
- Cache hit rate: >80%
- Response time: <500ms (99th percentile)
- Concurrent requests: 100 req/s

---

## Key Dependencies

**npm packages**:
```json
{
  "openpgp": "^5.11.1",
  "jsonwebtoken": "^9.0.2",
  "@cloudflare/workers-types": "^4.0.0"
}
```

**Cloudflare bindings**:
```toml
[[r2_buckets]]
binding = "VERIFICATION_CACHE"
bucket_name = "proofmode-verification-cache"
```

---

## What to Build

1. **Cloudflare Workers entry point** (`src/index.ts`)
2. **PGP verification module** (`src/pgp-verifier.ts`)
3. **iOS attestation validator** (`src/ios-attestation.ts`)
4. **Android attestation validator** (`src/android-attestation.ts`)
5. **Human activity analyzer** (`src/human-analyzer.ts`)
6. **Confidence scorer** (`src/confidence-scorer.ts`)
7. **R2 cache handler** (`src/cache.ts`)
8. **Error handlers** (`src/errors.ts`)

**Estimated Time**: 2-3 weeks for experienced Cloudflare Workers developer

---

## Example Usage

**From Mobile App**:
```dart
// Mobile app sends ProofManifest to verification server
final response = await http.post(
  'https://verify.divine.video/verify',
  body: jsonEncode({
    'proofManifest': manifest.toJson(),
    'publicKey': keyService.publicKey,
  }),
);

final result = VerificationResult.fromJson(response.body);

// Display badge based on verification level
if (result.verificationLevel == 'verified_mobile') {
  showProofBadge(icon: Icons.verified, color: Colors.green);
} else if (result.verificationLevel == 'basic_proof') {
  showProofBadge(icon: Icons.shield, color: Colors.orange);
}
```

---

## Security Notes

**Defend Against**:
- ✅ Replay attacks (verify challenge nonce unique)
- ✅ Signature forgery (OpenPGP cryptographic verification)
- ✅ Token replay (verify timestamp recent)
- ✅ Bot content (human activity pattern analysis)
- ✅ DDoS (rate limiting + Cloudflare protection)

**DO NOT**:
- ❌ Trust client-provided verification results
- ❌ Skip attestation token signature verification
- ❌ Accept old/expired attestation tokens (>1 hour)
- ❌ Bypass PGP verification for "trusted" users

---

## Questions for Implementation Team?

1. **Cloudflare Workers experience?** (TypeScript serverless functions)
2. **OpenPGP.js familiarity?** (PGP signature verification)
3. **Apple/Google attestation APIs?** (Need to integrate with both)
4. **R2 Storage experience?** (Object storage for caching)
5. **Target deployment timeline?** (2-3 weeks feasible?)

**Contact**: Pass to another agent for Cloudflare Workers implementation

**Full Requirements Doc**: `PROOFMODE_VERIFICATION_SERVER_REQUIREMENTS.md` (60+ pages, comprehensive)
