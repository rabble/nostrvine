// ABOUTME: Bulk thumbnail generation script for videos without thumbnails
// ABOUTME: Fetches Kind 22 events from vine.hol.is and generates thumbnails via API service

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/video_event.dart';
import '../services/thumbnail_api_service.dart';
import '../utils/unified_logger.dart';

/// Bulk thumbnail generation script
/// 
/// This script:
/// 1. Connects to vine.hol.is relay to fetch Kind 22 video events
/// 2. Filters events that don't have thumbnails
/// 3. Makes API requests to generate thumbnails for hosted videos
/// 4. Reports progress and statistics
class BulkThumbnailGenerator {
  static const String relayUrl = 'wss://vine.hol.is';
  static const String apiBaseUrl = 'https://api.openvine.co';
  static const int batchSize = 10; // Process videos in batches to avoid overwhelming the server
  static const int maxVideosToProcess = 1000; // Safety limit
  
  /// Statistics tracking
  static int totalVideosFound = 0;
  static int videosWithoutThumbnails = 0;
  static int thumbnailsGenerated = 0;
  static int thumbnailsFailed = 0;
  static int videosSkipped = 0;
  
  /// Main entry point for the script
  static Future<void> main(List<String> args) async {
    print('🚀 OpenVine Bulk Thumbnail Generator');
    print('====================================');
    
    // Parse command line arguments
    final options = _parseArguments(args);
    
    try {
      // Initialize logging - use existing configuration
      
      Log.info('Starting bulk thumbnail generation...', name: 'BulkThumbnailGenerator');
      
      // Step 1: Fetch video events from relay
      Log.info('Fetching Kind 22 events from $relayUrl...', name: 'BulkThumbnailGenerator');
      final videoEvents = await _fetchVideoEvents(options['limit'] ?? maxVideosToProcess);
      
      if (videoEvents.isEmpty) {
        print('❌ No video events found. Exiting.');
        return;
      }
      
      // Step 2: Filter events without thumbnails
      final eventsWithoutThumbnails = _filterEventsWithoutThumbnails(videoEvents);
      
      // Step 3: Generate thumbnails in batches
      await _generateThumbnailsInBatches(eventsWithoutThumbnails, options);
      
      // Step 4: Print final statistics
      _printFinalStatistics();
      
    } catch (e, stackTrace) {
      Log.error('Script failed: $e', name: 'BulkThumbnailGenerator');
      Log.error('Stack trace: $stackTrace', name: 'BulkThumbnailGenerator');
      print('❌ Script failed: $e');
      exit(1);
    }
  }
  
  /// Parse command line arguments
  static Map<String, dynamic> _parseArguments(List<String> args) {
    final options = <String, dynamic>{};
    
    for (int i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--limit':
        case '-l':
          if (i + 1 < args.length) {
            options['limit'] = int.tryParse(args[i + 1]) ?? maxVideosToProcess;
            i++; // Skip next argument
          }
          break;
        case '--dry-run':
        case '-d':
          options['dryRun'] = true;
          break;
        case '--batch-size':
        case '-b':
          if (i + 1 < args.length) {
            options['batchSize'] = int.tryParse(args[i + 1]) ?? batchSize;
            i++; // Skip next argument
          }
          break;
        case '--time-offset':
        case '-t':
          if (i + 1 < args.length) {
            options['timeOffset'] = double.tryParse(args[i + 1]) ?? 2.5;
            i++; // Skip next argument
          }
          break;
        case '--help':
        case '-h':
          _printUsage();
          return options; // Return instead of exit
      }
    }
    
    return options;
  }
  
  /// Print usage information
  static void _printUsage() {
    print('''
Usage: dart bulk_thumbnail_generator.dart [options]

Options:
  -l, --limit <number>       Maximum number of videos to process (default: $maxVideosToProcess)
  -d, --dry-run             Don't actually generate thumbnails, just report what would be done
  -b, --batch-size <number>  Number of videos to process in each batch (default: $batchSize)
  -t, --time-offset <number> Time offset in seconds for thumbnail extraction (default: 2.5)
  -h, --help                Show this help message

Examples:
  dart bulk_thumbnail_generator.dart --limit 100 --dry-run
  dart bulk_thumbnail_generator.dart --batch-size 5 --time-offset 3.0
    ''');
  }
  
  /// Fetch video events from the relay using HTTP REST API
  static Future<List<VideoEvent>> _fetchVideoEvents(int limit) async {
    final videoEvents = <VideoEvent>[];
    
    try {
      // Use REST API to fetch events (simpler than WebSocket for batch processing)
      final url = 'https://vine.hol.is/api/events?kinds=22&limit=$limit';
      
      Log.info('Making HTTP request to: $url', name: 'BulkThumbnailGenerator');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OpenVine-ThumbnailGenerator/1.0',
        },
      ).timeout(Duration(seconds: 30));
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      
      final jsonData = json.decode(response.body);
      
      if (jsonData is! List) {
        throw Exception('Expected array of events, got: ${jsonData.runtimeType}');
      }
      
      Log.info('Received ${jsonData.length} events from relay', name: 'BulkThumbnailGenerator');
      
      // Parse events
      for (final eventData in jsonData) {
        try {
          // Convert to the format expected by VideoEvent.fromNostrEvent
          final mockEvent = _createMockNostrEvent(eventData);
          final videoEvent = VideoEvent.fromNostrEvent(mockEvent);
          
          if (videoEvent.hasVideo) {
            videoEvents.add(videoEvent);
            totalVideosFound++;
          }
        } catch (e) {
          Log.debug('Skipped event ${eventData['id']}: $e', name: 'BulkThumbnailGenerator');
        }
      }
      
      Log.info('Successfully parsed ${videoEvents.length} video events', name: 'BulkThumbnailGenerator');
      
    } catch (e) {
      Log.error('Failed to fetch events from relay: $e', name: 'BulkThumbnailGenerator');
      
      // Fallback: return sample events for testing
      Log.info('Using fallback sample events for testing...', name: 'BulkThumbnailGenerator');
      return _getSampleVideoEvents();
    }
    
    return videoEvents;
  }
  
  /// Create a mock Nostr event from JSON data
  static dynamic _createMockNostrEvent(Map<String, dynamic> eventData) {
    return MockNostrEvent(
      id: eventData['id'] ?? '',
      pubkey: eventData['pubkey'] ?? '',
      kind: eventData['kind'] ?? 22,
      createdAt: eventData['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: eventData['content'] ?? '',
      tags: eventData['tags'] ?? [],
    );
  }
  
  /// Filter events that don't have thumbnails
  static List<VideoEvent> _filterEventsWithoutThumbnails(List<VideoEvent> events) {
    final filtered = <VideoEvent>[];
    
    for (final event in events) {
      if (event.effectiveThumbnailUrl == null) {
        filtered.add(event);
        videosWithoutThumbnails++;
      }
    }
    
    print('📊 Found $totalVideosFound total video events');
    print('📊 $videosWithoutThumbnails videos without thumbnails');
    print('📊 ${totalVideosFound - videosWithoutThumbnails} videos already have thumbnails');
    
    return filtered;
  }
  
  /// Generate thumbnails in batches
  static Future<void> _generateThumbnailsInBatches(
    List<VideoEvent> events, 
    Map<String, dynamic> options
  ) async {
    final isDryRun = options['dryRun'] == true;
    final batchSizeToUse = options['batchSize'] ?? batchSize;
    final timeOffset = options['timeOffset'] ?? 2.5;
    
    if (isDryRun) {
      print('🔍 DRY RUN: Would generate thumbnails for ${events.length} videos');
      return;
    }
    
    print('🎬 Generating thumbnails for ${events.length} videos...');
    print('⚙️ Batch size: $batchSizeToUse');
    print('⏱️ Time offset: ${timeOffset}s');
    
    for (int i = 0; i < events.length; i += batchSizeToUse) {
      final batch = events.skip(i).take(batchSizeToUse).toList();
      final batchNumber = (i ~/ batchSizeToUse) + 1;
      final totalBatches = (events.length / batchSizeToUse).ceil();
      
      print('\n📦 Processing batch $batchNumber/$totalBatches (${batch.length} videos)...');
      
      // Process batch concurrently but with limited concurrency
      final futures = batch.map((event) => _generateThumbnailForEvent(event, timeOffset));
      await Future.wait(futures);
      
      // Brief pause between batches to avoid overwhelming the server
      if (i + batchSizeToUse < events.length) {
        await Future.delayed(Duration(seconds: 2));
      }
    }
  }
  
  /// Generate thumbnail for a single video event
  static Future<void> _generateThumbnailForEvent(VideoEvent event, double timeOffset) async {
    try {
      Log.info('Generating thumbnail for video ${event.id.substring(0, 8)}...', 
        name: 'BulkThumbnailGenerator');
      
      final thumbnailUrl = await ThumbnailApiService.getThumbnailWithFallback(
        event.id,
        timeSeconds: timeOffset,
        size: ThumbnailSize.medium,
      );
      
      if (thumbnailUrl != null) {
        thumbnailsGenerated++;
        print('✅ Generated thumbnail for ${event.id.substring(0, 8)}: $thumbnailUrl');
      } else {
        thumbnailsFailed++;
        print('❌ Failed to generate thumbnail for ${event.id.substring(0, 8)}');
      }
      
    } catch (e) {
      thumbnailsFailed++;
      Log.error('Failed to generate thumbnail for ${event.id.substring(0, 8)}: $e', 
        name: 'BulkThumbnailGenerator');
      print('❌ Error generating thumbnail for ${event.id.substring(0, 8)}: $e');
    }
  }
  
  /// Print final statistics
  static void _printFinalStatistics() {
    print('\n📈 FINAL STATISTICS');
    print('===================');
    print('Total videos found: $totalVideosFound');
    print('Videos without thumbnails: $videosWithoutThumbnails');
    print('Thumbnails generated: $thumbnailsGenerated');
    print('Thumbnails failed: $thumbnailsFailed');
    print('Videos skipped: $videosSkipped');
    
    final successRate = videosWithoutThumbnails > 0 
      ? (thumbnailsGenerated / videosWithoutThumbnails * 100.0).toStringAsFixed(1)
      : '0.0';
    print('Success rate: $successRate%');
    
    if (thumbnailsGenerated > 0) {
      print('🎉 Successfully generated $thumbnailsGenerated thumbnails!');
    }
    
    if (thumbnailsFailed > 0) {
      print('⚠️ $thumbnailsFailed thumbnails failed to generate');
    }
  }
  
  /// Get sample video events for testing when relay is unavailable
  static List<VideoEvent> _getSampleVideoEvents() {
    return [
      VideoEvent(
        id: '87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344',
        pubkey: '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Sample video without thumbnail',
        timestamp: DateTime.now(),
        videoUrl: 'https://blossom.primal.net/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344.mp4',
        thumbnailUrl: null, // No thumbnail
        duration: 5,
        hashtags: ['sample', 'test'],
      ),
    ];
  }
}

/// Mock Nostr event for testing
class MockNostrEvent {
  final String id;
  final String pubkey;
  final int kind;
  final int createdAt;
  final String content;
  final List<dynamic> tags;
  
  MockNostrEvent({
    required this.id,
    required this.pubkey,
    required this.kind,
    required this.createdAt,
    required this.content,
    required this.tags,
  });
}

/// Entry point when run as script
void main(List<String> args) async {
  await BulkThumbnailGenerator.main(args);
}