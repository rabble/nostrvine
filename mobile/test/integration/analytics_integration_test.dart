import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('Analytics Integration Tests', () {
    test('Analytics trending endpoint returns valid data', () async {
      final response = await http.get(
        Uri.parse('https://analytics.openvine.co/analytics/trending/vines'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OpenVine-Mobile-Test/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      expect(response.statusCode, 200);
      
      final data = jsonDecode(response.body);
      expect(data, isA<Map<String, dynamic>>());
      expect(data['vines'], isA<List>());
      
      // Check that we have at least some trending videos
      final vines = data['vines'] as List;
      if (vines.isNotEmpty) {
        final firstVine = vines.first;
        expect(firstVine['eventId'], isA<String>());
        expect(firstVine['views'], isA<num>());
        expect(firstVine['score'], isA<num>());
        
        // Event ID should be a valid hex string (64 chars for SHA-256)
        final eventId = firstVine['eventId'] as String;
        expect(eventId.length, 64);
        expect(RegExp(r'^[a-f0-9]+$').hasMatch(eventId), true);
      }
      
      print('✅ Analytics API integration test passed');
      print('   Trending videos found: ${vines.length}');
    });

    test('Analytics API handles errors gracefully', () async {
      // Test with invalid endpoint
      final response = await http.get(
        Uri.parse('https://analytics.openvine.co/analytics/invalid'),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OpenVine-Mobile-Test/1.0',
        },
      ).timeout(const Duration(seconds: 10));

      expect(response.statusCode, 404);
      
      print('✅ Analytics API error handling test passed');
    });
  });
}