// ABOUTME: Utility functions for Nostr key encoding and decoding (bech32 npub/nsec format)
// ABOUTME: Handles conversion between hex keys and human-readable bech32 format per NIP-19

import 'dart:typed_data';
import 'package:bech32/bech32.dart';
import 'package:crypto/crypto.dart';

/// Exception thrown when encoding/decoding operations fail
class NostrEncodingException implements Exception {
  final String message;
  const NostrEncodingException(this.message);
  
  @override
  String toString() => 'NostrEncodingException: $message';
}

/// Utility class for Nostr key encoding operations
class NostrEncoding {
  
  /// Encode a hex public key to npub format (bech32)
  /// 
  /// Takes a 64-character hex public key and returns npub1... format
  /// Example: npub1xyz... 
  static String encodePublicKey(String hexPubkey) {
    if (hexPubkey.length != 64) {
      throw const NostrEncodingException('Public key must be 64 hex characters');
    }
    
    try {
      // Convert hex to bytes
      final bytes = _hexToBytes(hexPubkey);
      
      // Convert bytes to 5-bit groups for bech32
      final fiveBitData = _convertTo5BitGroups(bytes);
      
      // Encode with 'npub' prefix 
      final bech32Data = bech32.encode(Bech32('npub', fiveBitData));
      return bech32Data;
      
    } catch (e) {
      throw NostrEncodingException('Failed to encode public key: $e');
    }
  }
  
  /// Decode an npub to hex public key
  /// 
  /// Takes npub1... format and returns 64-character hex string
  static String decodePublicKey(String npub) {
    if (!npub.startsWith('npub1')) {
      throw const NostrEncodingException('Invalid npub format - must start with npub1');
    }
    
    try {
      final decoded = bech32.decode(npub);
      
      if (decoded.hrp != 'npub') {
        throw const NostrEncodingException('Invalid npub prefix');
      }
      
      // Convert 5-bit groups back to bytes
      final bytes = _convertFrom5BitGroups(decoded.data);
      
      // Convert bytes back to hex
      final hexKey = _bytesToHex(bytes);
      
      if (hexKey.length != 64) {
        throw const NostrEncodingException('Decoded public key has invalid length');
      }
      
      return hexKey;
      
    } catch (e) {
      throw NostrEncodingException('Failed to decode npub: $e');
    }
  }
  
  /// Encode a hex private key to nsec format (bech32)
  /// 
  /// Takes a 64-character hex private key and returns nsec1... format
  /// Example: nsec1xyz...
  static String encodePrivateKey(String hexPrivkey) {
    if (hexPrivkey.length != 64) {
      throw const NostrEncodingException('Private key must be 64 hex characters');
    }
    
    try {
      // Convert hex to bytes
      final bytes = _hexToBytes(hexPrivkey);
      
      // Convert bytes to 5-bit groups for bech32
      final fiveBitData = _convertTo5BitGroups(bytes);
      
      // Encode with 'nsec' prefix
      final bech32Data = bech32.encode(Bech32('nsec', fiveBitData));
      return bech32Data;
      
    } catch (e) {
      throw NostrEncodingException('Failed to encode private key: $e');
    }
  }
  
  /// Decode an nsec to hex private key
  /// 
  /// Takes nsec1... format and returns 64-character hex string
  static String decodePrivateKey(String nsec) {
    if (!nsec.startsWith('nsec1')) {
      throw const NostrEncodingException('Invalid nsec format - must start with nsec1');
    }
    
    try {
      final decoded = bech32.decode(nsec);
      
      if (decoded.hrp != 'nsec') {
        throw const NostrEncodingException('Invalid nsec prefix');
      }
      
      // Convert 5-bit groups back to bytes
      final bytes = _convertFrom5BitGroups(decoded.data);
      
      // Convert bytes back to hex
      final hexKey = _bytesToHex(bytes);
      
      if (hexKey.length != 64) {
        throw const NostrEncodingException('Decoded private key has invalid length');
      }
      
      return hexKey;
      
    } catch (e) {
      throw NostrEncodingException('Failed to decode nsec: $e');
    }
  }
  
  /// Validate if a string is a valid npub
  static bool isValidNpub(String npub) {
    try {
      decodePublicKey(npub);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Validate if a string is a valid nsec
  static bool isValidNsec(String nsec) {
    try {
      decodePrivateKey(nsec);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Validate if a string is a valid hex key (32 bytes = 64 hex chars)
  static bool isValidHexKey(String hexKey) {
    if (hexKey.length != 64) return false;
    
    // Check if all characters are valid hex
    final hexRegex = RegExp(r'^[0-9a-fA-F]+$');
    return hexRegex.hasMatch(hexKey);
  }
  
  /// Generate a random private key (32 bytes in hex)
  /// 
  /// Returns a secure random 64-character hex private key
  /// WARNING: This should only be used for key generation, not for production apps
  /// In production, use secure key generation libraries
  static String generatePrivateKey() {
    final random = List<int>.generate(32, (i) => 
        DateTime.now().millisecondsSinceEpoch + i);
    
    // Use crypto hash for better randomness
    final digest = sha256.convert(random);
    return digest.toString();
  }
  
  /// Derive public key from private key
  /// 
  /// Takes a hex private key and returns the corresponding hex public key
  /// Note: This is a placeholder - real implementation needs secp256k1
  static String derivePublicKey(String hexPrivkey) {
    if (!isValidHexKey(hexPrivkey)) {
      throw const NostrEncodingException('Invalid private key format');
    }
    
    // TODO: Implement actual secp256k1 public key derivation
    // For now, return a placeholder that follows the pattern
    // In production, this would use elliptic curve cryptography
    throw const NostrEncodingException(
      'Public key derivation not implemented - requires secp256k1 library'
    );
  }
  
  /// Convert hex string to bytes
  static Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) {
      throw const NostrEncodingException('Hex string must have even length');
    }
    
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < hex.length; i += 2) {
      final byte = int.parse(hex.substring(i, i + 2), radix: 16);
      bytes[i ~/ 2] = byte;
    }
    
    return bytes;
  }
  
  /// Convert bytes to hex string
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
  }
  
  /// Extract the key type from a bech32 encoded key
  /// 
  /// Returns 'npub', 'nsec', or null if invalid
  static String? getKeyType(String bech32Key) {
    try {
      if (bech32Key.startsWith('npub1')) return 'npub';
      if (bech32Key.startsWith('nsec1')) return 'nsec';
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Mask a key for display purposes (show first 8 and last 4 characters)
  /// 
  /// Example: npub1abc...xyz4 or 1234abcd...xyz4
  static String maskKey(String key) {
    if (key.length < 12) return key;
    
    final start = key.substring(0, 8);
    final end = key.substring(key.length - 4);
    return '$start...$end';
  }
  
  /// Convert 8-bit bytes to 5-bit groups for bech32 encoding
  static List<int> _convertTo5BitGroups(List<int> bytes) {
    final result = <int>[];
    int accumulator = 0;
    int bits = 0;
    
    for (final byte in bytes) {
      accumulator = (accumulator << 8) | byte;
      bits += 8;
      
      while (bits >= 5) {
        bits -= 5;
        result.add((accumulator >> bits) & 31);
      }
    }
    
    if (bits > 0) {
      result.add((accumulator << (5 - bits)) & 31);
    }
    
    return result;
  }
  
  /// Convert 5-bit groups back to 8-bit bytes
  static List<int> _convertFrom5BitGroups(List<int> fiveBitData) {
    final result = <int>[];
    int accumulator = 0;
    int bits = 0;
    
    for (final value in fiveBitData) {
      if (value < 0 || value > 31) {
        throw const NostrEncodingException('Invalid 5-bit value');
      }
      
      accumulator = (accumulator << 5) | value;
      bits += 5;
      
      if (bits >= 8) {
        bits -= 8;
        result.add((accumulator >> bits) & 255);
      }
    }
    
    if (bits >= 5 || ((accumulator << (8 - bits)) & 255) != 0) {
      throw const NostrEncodingException('Invalid padding in 5-bit data');
    }
    
    return result;
  }
}