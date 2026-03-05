# App Encryption Export Compliance Documentation

**App Name**: Divine (OpenVine)
**Bundle Identifier**: com.openvine.divine
**Date**: November 12, 2025
**Document Purpose**: Apple App Store encryption export compliance declaration

## Executive Summary

**Divine uses encryption: YES**
**Uses non-exempt encryption: NO**
**ITSAppUsesNonExemptEncryption value: `false`**

This app uses only **standard, publicly available encryption algorithms** that are accepted by international standards bodies (IETF, NIST, SECG). All cryptographic implementations are open-source and publicly documented. No proprietary or custom encryption algorithms are used.

---

## Encryption Usage Declaration

### 1. Transport Layer Encryption (Exempt)
**Protocol**: HTTPS/TLS 1.2 and TLS 1.3
**Standards**: IETF RFCs 5246, 8446
**Purpose**: Secure network communications to relays and media servers
**Classification**: **EXEMPT** - Standard transport security

### 2. Nostr Protocol Cryptography (Standard Algorithms)
**Primary Algorithm**: secp256k1 Elliptic Curve Cryptography
**Standards**:
- SECG SEC2 v2.0 (Standards for Efficient Cryptography Group)
- Used in Bitcoin (BIP-340 Schnorr signatures)

**Purpose**:
- Key pair generation (public/private keys)
- Event signing (ECDSA signatures)
- Key exchange for encrypted messages (ECDH)

**Operations**:
- Digital signatures for all published events
- Diffie-Hellman key exchange for end-to-end encryption

**Classification**: **STANDARD** - Publicly documented elliptic curve

### 3. NIP-44 Encrypted Direct Messages (Standard Algorithms)
**Algorithm**: ChaCha20-Poly1305 AEAD
**Standard**: IETF RFC 8439
**Key Exchange**: ECDH using secp256k1
**Key Derivation**: HKDF-SHA256 (IETF RFC 5869)

**Purpose**: End-to-end encrypted private messages between users
**Implementation**: Nostr Implementation Possibility #44 (NIP-44)
**Public Specification**: https://github.com/nostr-protocol/nips/blob/master/44.md

**Classification**: **STANDARD** - IETF-standardized symmetric encryption

### 4. NIP-04 Encrypted Messages (Legacy, Standard Algorithms)
**Algorithm**: AES-256-CBC
**Standard**: FIPS 197 (Advanced Encryption Standard), NIST approved
**Key Exchange**: ECDH using secp256k1
**Note**: Deprecated in favor of NIP-44, maintained for backward compatibility

**Purpose**: Legacy encrypted direct messages
**Classification**: **STANDARD** - NIST-approved symmetric encryption

### 5. NIP-59 Gift Wrap Encryption (Standard Algorithms)
**Algorithms**:
- ChaCha20-Poly1305 (IETF RFC 8439)
- secp256k1 ECDH (SECG SEC2)

**Purpose**: Anonymous message delivery using ephemeral keys
**Implementation**: Three-layer encryption:
1. Kind 14 rumor (unsigned message)
2. Kind 13 seal (signed and encrypted by sender)
3. Kind 1059 gift wrap (encrypted with random ephemeral key)

**Public Specification**: https://github.com/nostr-protocol/nips/blob/master/59.md
**Classification**: **STANDARD** - Combination of IETF and SECG standards

### 6. PGP/OpenPGP Signatures (Standard Algorithms)
**Algorithms**:
- RSA-2048 key generation
- SHA-256 hashing

**Standards**:
- RFC 4880 (OpenPGP Message Format)
- RFC 8017 (PKCS #1: RSA Cryptography Specifications)

**Purpose**: Digital signatures for video attestation (ProofMode feature)
**Libraries**:
- `dart_pg` v2.0.0
- `openpgp` v3.10.7

**Classification**: **STANDARD** - IETF-standardized public key cryptography

### 7. Local Secure Storage (OS-Provided, Exempt)
**iOS Implementation**: iOS Keychain
**Android Implementation**: Android Keystore
**Library**: `flutter_secure_storage` v9.0.0

**Purpose**: Secure storage of private keys on device
**Encryption**: Uses OS-provided encryption mechanisms
**Classification**: **EXEMPT** - Operating system security features

---

## Cryptographic Libraries Used

| Library | Version | Purpose | Algorithms |
|---------|---------|---------|------------|
| `nostr_sdk` | custom | Nostr protocol | secp256k1, ChaCha20-Poly1305, AES-256-CBC |
| `crypto` | 3.0.7 | Hashing | SHA-256, SHA-512 |
| `encrypt` | 5.0.3 | Symmetric encryption | AES (via Nostr SDK) |
| `dart_pg` | 2.0.0 | PGP signatures | RSA-2048, SHA-256 |
| `openpgp` | 3.10.7 | OpenPGP | RSA, SHA-256 |
| `flutter_secure_storage` | 9.0.0 | Keychain/Keystore | OS-provided |
| `bech32` | 0.2.2 | Encoding | N/A (encoding only) |

All libraries use **publicly available, open-source implementations** of standard cryptographic algorithms.

---

## Standards Compliance

### International Standards Bodies

All encryption algorithms used in this app are defined by recognized international standards organizations:

1. **IETF (Internet Engineering Task Force)**
   - ChaCha20-Poly1305: RFC 8439
   - HKDF-SHA256: RFC 5869
   - TLS 1.2/1.3: RFCs 5246, 8446
   - OpenPGP: RFC 4880

2. **NIST (National Institute of Standards and Technology)**
   - AES: FIPS 197
   - SHA-256: FIPS 180-4

3. **SECG (Standards for Efficient Cryptography Group)**
   - secp256k1: SECG SEC2 v2.0

4. **ISO/IEC**
   - RSA: ISO/IEC 9796

### Nostr Protocol Documentation

All Nostr-specific cryptographic protocols are publicly documented:
- **Repository**: https://github.com/nostr-protocol/nips
- **License**: Public Domain (CC0-1.0)
- **NIPs Implemented**: 22 different Nostr Implementation Possibilities

---

## Export Control Classification

### U.S. Export Administration Regulations (EAR)

**ECCN Classification**: Likely **5D992.c** (Mass market encryption software)
**Reasoning**:
- Uses only standard, publicly available cryptographic algorithms
- No proprietary or classified encryption
- Publicly available source code

**License Exception**: **ENC** (Encryption commodities, software, and technology)
**Self-Classification**: Permitted under 15 CFR 740.17(b)(1)

### EU Export Controls

**EU Dual-Use Regulation**: Council Regulation (EC) No 428/2009
**Classification**: Category 5 Part 2 (Information Security)
**Status**: Generally exempt for mass-market cryptography using standard algorithms

### France-Specific Requirements

France follows EU regulations but may require:
1. ✅ **Documentation of encryption methods** (this document)
2. ✅ **Confirmation of standard algorithms** (all algorithms listed are standard)
3. ✅ **No backdoors or proprietary crypto** (all implementations are open-source)
4. ⚠️ **Possible year-end self-classification report** to French authorities

**Note**: For French market, consult with ANSSI (Agence nationale de la sécurité des systèmes d'information) if required.

---

## Compliance Checklist

### Apple App Store Requirements

- [x] `ITSAppUsesNonExemptEncryption` key present in Info.plist
- [x] Value set to `false` (uses only exempt/standard encryption)
- [x] Encryption documentation prepared (this document)
- [x] All algorithms are standard and publicly available
- [x] No proprietary encryption used
- [x] No custom cryptographic implementations

### U.S. Export Compliance

- [x] All encryption algorithms are publicly available
- [x] Encryption is not the primary function of the app
- [x] App qualifies for License Exception ENC
- [ ] Annual self-classification report to BIS (if required)
- [ ] TSU notification (if first-time exporter)

### EU/France Export Compliance

- [x] Uses only standard, publicly documented algorithms
- [x] No classified or military-grade encryption
- [x] Open-source cryptographic implementations
- [ ] ANSSI notification (if required for French market)

---

## Justification for ITSAppUsesNonExemptEncryption = false

This app sets `ITSAppUsesNonExemptEncryption` to **false** because:

1. **HTTPS/TLS Only**: Primary network security uses standard HTTPS/TLS, which is explicitly exempt

2. **Standard Algorithms Only**: All encryption beyond HTTPS uses algorithms that are:
   - Publicly documented by standards bodies (IETF, NIST, SECG)
   - Widely used and peer-reviewed
   - Available in open-source libraries
   - Not proprietary or classified

3. **No Custom Cryptography**: Zero custom or modified cryptographic primitives

4. **Publicly Available**: All cryptographic implementations are:
   - Open-source (MIT/Apache licenses)
   - Peer-reviewed
   - Independently auditable

5. **Encryption is Not Primary Function**: The app is a social video sharing platform; encryption is used for:
   - Secure communications (HTTPS)
   - User authentication (key signing)
   - Optional private messages (E2EE)

### Apple's Exempt Encryption Criteria

According to Apple's documentation, encryption is **exempt** if it meets these criteria:

✅ **Uses encryption within Apple's operating system** - Uses iOS Keychain
✅ **Uses standard encryption algorithms** - All algorithms are IETF/NIST/SECG standard
✅ **Encryption for authentication only** - Key signing, user authentication
✅ **Uses encryption for data protection at rest** - Keychain storage
✅ **Standard HTTPS/TLS** - All network communications

This app meets **all** exempt criteria.

---

## Technical Implementation Details

### Key Generation
- **Algorithm**: secp256k1 (SECG SEC2)
- **Key Size**: 256-bit private key, 33-byte compressed public key
- **Randomness**: OS-provided secure random number generator
- **Storage**: iOS Keychain (AES-256 encrypted by OS)

### Message Encryption (NIP-44)
1. **Key Exchange**: ECDH using secp256k1 to derive shared secret
2. **Key Derivation**: HKDF-SHA256 (IETF RFC 5869)
3. **Encryption**: ChaCha20-Poly1305 AEAD (IETF RFC 8439)
4. **Nonce**: 12-byte random nonce (unique per message)
5. **Authentication**: Poly1305 MAC (128-bit tag)

### Event Signing
1. **Hash**: SHA-256 of event JSON
2. **Signature**: Schnorr signature using secp256k1 private key
3. **Verification**: Recipients verify using secp256k1 public key

### Video Attestation (ProofMode)
1. **Hash**: SHA-256 of video file
2. **Signature**: RSA-2048 signature using PGP key
3. **Certificate**: Optional PGP certificate chain
4. **Timestamp**: Signed timestamp for integrity

---

## Open Source Verification

All cryptographic implementations can be verified at:

1. **Nostr SDK**: `/nostr_sdk/` (local package)
   - NIP implementations: `/nostr_sdk/lib/nips/`
   - Cryptography: `/nostr_sdk/lib/crypto/`

2. **App Implementation**: `/mobile/lib/services/`
   - NIP-17 messages: `nip17_message_service.dart`
   - Key management: `nostr_key_manager.dart`
   - ProofMode: `proofmode_key_service.dart`

3. **Third-Party Libraries**:
   - dart_pg: https://pub.dev/packages/dart_pg
   - openpgp: https://pub.dev/packages/openpgp
   - encrypt: https://pub.dev/packages/encrypt
   - crypto: https://pub.dev/packages/crypto

---

## Annual Reporting Requirements

### U.S. Bureau of Industry and Security (BIS)

If the app is exported from the U.S., annual reporting may be required:

**Report Type**: Self-Classification Report for Encryption Items
**Deadline**: February 1st (for previous calendar year)
**Submission**: Via SNAP-R system (https://snapr.bis.doc.gov/)

**Required Information**:
- Product name and model number
- Encryption algorithms and key lengths
- Export Control Classification Number (ECCN)
- Countries of export
- Number of units exported

**Note**: Consult with legal counsel or export compliance specialist for specific requirements.

### France/EU Reporting

France may require notification to ANSSI for:
- Apps using encryption distributed to French users
- First-time distribution in France

**Contact**: ANSSI (https://www.ssi.gouv.fr/)

---

## Conclusion

**Divine (OpenVine)** uses encryption exclusively for:
1. Secure network communications (HTTPS/TLS)
2. User authentication and event signing (secp256k1)
3. Optional end-to-end encrypted messaging (NIP-44, NIP-59)
4. Video integrity attestation (PGP signatures)
5. Secure key storage (iOS Keychain)

**All encryption uses standard, publicly available algorithms** accepted by international standards bodies. There are **no proprietary algorithms**, **no custom cryptography**, and **no classified encryption methods**.

**The app qualifies as using only exempt encryption** and correctly declares `ITSAppUsesNonExemptEncryption = false` in its Info.plist.

---

## Document History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-12 | 1.0 | Initial encryption export compliance documentation |

---

## Contact Information

For questions regarding this encryption export compliance documentation, contact:

**Developer**: OpenVine Project
**Email**: [Contact email for compliance inquiries]
**Repository**: https://github.com/rabble/nostrvine

---

## Disclaimer

This document is provided for informational purposes and represents the app's current encryption implementation as of the date listed. Export control regulations may change, and developers should consult with legal counsel or export compliance specialists for specific advice regarding their obligations under U.S., EU, and French export control laws.
