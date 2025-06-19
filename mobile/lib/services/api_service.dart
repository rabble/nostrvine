// ABOUTME: HTTP API service for communicating with the NostrVine backend
// ABOUTME: Handles ready events polling, authentication, and error handling

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ready_event_data.dart';
import '../config/app_config.dart';

/// Exception thrown by API service
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;
  
  const ApiException(this.message, {this.statusCode, this.responseBody});
  
  @override
  String toString() => 'ApiException: $message (${statusCode ?? 'no status'})';
}

/// Service for backend API communication
class ApiService extends ChangeNotifier {
  static String get _baseUrl => AppConfig.backendBaseUrl;
  static const Duration _defaultTimeout = Duration(seconds: 30);
  
  final http.Client _client;
  
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Get ready events from the backend
  Future<List<ReadyEventData>> getReadyEvents() async {
    debugPrint('🌐 Fetching ready events from backend');
    
    try {
      final uri = Uri.parse('$_baseUrl/v1/media/ready-events');
      
      final response = await _client.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(_defaultTimeout);
      
      debugPrint('📡 API Response: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final events = (data['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
        
        final readyEvents = events
            .map((eventJson) => ReadyEventData.fromJson(eventJson))
            .toList();
        
        debugPrint('✅ Fetched ${readyEvents.length} ready events');
        return readyEvents;
        
      } else if (response.statusCode == 204 || response.statusCode == 404) {
        // No ready events available
        debugPrint('📭 No ready events available (${response.statusCode})');
        return [];
        
      } else {
        throw ApiException(
          'Failed to fetch ready events',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      
    } on TimeoutException {
      throw const ApiException('Request timeout while fetching ready events');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: $e');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  /// Clean up a processed event on the backend
  Future<void> cleanupRemoteEvent(String publicId) async {
    debugPrint('🧹 Cleaning up remote event: $publicId');
    
    try {
      final uri = Uri.parse('$_baseUrl/v1/media/cleanup/$publicId');
      
      final response = await _client.delete(
        uri,
        headers: await _getHeaders(),
      ).timeout(_defaultTimeout);
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('✅ Remote event cleaned up: $publicId');
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Remote event not found (already cleaned?): $publicId');
      } else {
        throw ApiException(
          'Failed to cleanup remote event',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      
    } on TimeoutException {
      throw const ApiException('Request timeout while cleaning up event');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during cleanup: $e');
    }
  }

  /// Request signed upload parameters (from previous implementation)
  Future<Map<String, dynamic>> requestSignedUpload({
    required String nostrPubkey,
    required int fileSize,
    required String mimeType,
    String? title,
    String? description,
    List<String>? hashtags,
  }) async {
    debugPrint('🔐 Requesting signed upload parameters');
    
    try {
      final uri = Uri.parse('$_baseUrl/v1/media/request-upload');
      
      final requestBody = {
        'nostr_pubkey': nostrPubkey,
        'file_size': fileSize,
        'mime_type': mimeType,
        'title': title,
        'description': description,
        'hashtags': hashtags,
      };
      
      final response = await _client.post(
        uri,
        headers: await _getHeaders(),
        body: jsonEncode(requestBody),
      ).timeout(_defaultTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Received signed upload parameters');
        return data;
      } else {
        throw ApiException(
          'Failed to get signed upload parameters',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      
    } on TimeoutException {
      throw const ApiException('Request timeout for signed upload');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during signed upload request: $e');
    }
  }

  /// Get user's upload status
  Future<Map<String, dynamic>> getUserUploadStatus() async {
    debugPrint('📊 Fetching user upload status');
    
    try {
      final uri = Uri.parse('$_baseUrl/v1/media/status');
      
      final response = await _client.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(_defaultTimeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ Retrieved upload status');
        return data;
      } else {
        throw ApiException(
          'Failed to get upload status',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
      
    } on TimeoutException {
      throw const ApiException('Request timeout for upload status');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error during status request: $e');
    }
  }

  /// Get standard headers for API requests
  Future<Map<String, String>> _getHeaders() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${await _getNip98Token()}',
      'User-Agent': 'NostrVine-Mobile/1.0',
    };
  }

  /// Generate NIP-98 authentication token
  Future<String> _getNip98Token() async {
    // TODO: Implement proper NIP-98 authentication
    // This should create a signed event for HTTP authentication
    debugPrint('⚠️ TODO: Implement NIP-98 authentication');
    return 'placeholder-nip98-token';
  }

  /// Test API connectivity
  Future<bool> testConnection() async {
    try {
      debugPrint('🔗 Testing API connection to: ${AppConfig.healthUrl}');
      
      final uri = Uri.parse(AppConfig.healthUrl);
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));
      
      final isHealthy = response.statusCode == 200;
      debugPrint(isHealthy ? '✅ API connection healthy' : '❌ API connection unhealthy');
      
      if (isHealthy) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('📊 Backend status: ${data['status']}');
        } catch (e) {
          // Ignore JSON parsing errors for health check
        }
      }
      
      return isHealthy;
      
    } catch (e) {
      debugPrint('❌ API connection test failed: $e');
      return false;
    }
  }

  /// Get API configuration info
  Future<Map<String, dynamic>?> getApiConfig() async {
    try {
      final uri = Uri.parse('$_baseUrl/v1/config');
      final response = await _client.get(uri, headers: await _getHeaders()).timeout(_defaultTimeout);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to get API config: $e');
    }
    return null;
  }

  /// Close the HTTP client
  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}