// Debug script to test Editor's Picks functionality

import 'package:flutter/widgets.dart';
import 'dart:async';
import 'lib/services/nostr_service.dart';
import 'lib/services/video_event_service.dart';
import 'lib/services/curation_service.dart';
import 'lib/services/social_service.dart';
import 'lib/services/subscription_manager.dart';
import 'lib/models/curation_set.dart';
import 'lib/utils/unified_logger.dart';
import 'lib/constants/app_constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Log.info('🔍 Starting Editor\'s Picks Debug Test', name: 'Debug', category: LogCategory.system);
  Log.info('Classic Vines Pubkey: ${AppConstants.classicVinesPubkey}', name: 'Debug', category: LogCategory.system);
  
  // Initialize services
  final nostrService = NostrService();
  final subscriptionManager = SubscriptionManager(nostrService: nostrService);
  final videoEventService = VideoEventService(
    nostrService,
    subscriptionManager: subscriptionManager,
  );
  final socialService = SocialService(
    nostrService,
    subscriptionManager: subscriptionManager,
  );
  final curationService = CurationService(
    nostrService: nostrService,
    videoEventService: videoEventService,
    socialService: socialService,
  );
  
  try {
    // Connect to relay
    Log.info('Connecting to Nostr relays...', name: 'Debug', category: LogCategory.system);
    await nostrService.initialize();
    
    // Add vine.hol.is relay
    final relayUrl = 'wss://vine.hol.is';
    Log.info('Adding relay: $relayUrl', name: 'Debug', category: LogCategory.system);
    final connected = await nostrService.addRelay(relayUrl);
    
    if (!connected) {
      Log.error('Failed to connect to relay', name: 'Debug', category: LogCategory.system);
      return;
    }
    
    Log.info('Connected to relay successfully', name: 'Debug', category: LogCategory.system);
    
    // Subscribe to videos from Classic Vines pubkey
    Log.info('Subscribing to videos from Classic Vines account...', name: 'Debug', category: LogCategory.system);
    await videoEventService.subscribeToVideoFeed(
      authors: [AppConstants.classicVinesPubkey],
      limit: 50,
    );
    
    // Wait for events to load
    Log.info('Waiting for events to load...', name: 'Debug', category: LogCategory.system);
    await Future.delayed(const Duration(seconds: 5));
    
    // Check what videos we have
    final allVideos = videoEventService.videoEvents;
    Log.info('Total videos loaded: ${allVideos.length}', name: 'Debug', category: LogCategory.system);
    
    // Check videos from Classic Vines pubkey
    final classicVinesVideos = allVideos.where((v) => v.pubkey == AppConstants.classicVinesPubkey).toList();
    Log.info('Videos from Classic Vines: ${classicVinesVideos.length}', name: 'Debug', category: LogCategory.system);
    
    // Print details of Classic Vines videos
    for (int i = 0; i < classicVinesVideos.length && i < 5; i++) {
      final video = classicVinesVideos[i];
      Log.info('Classic Vine ${i + 1}:', name: 'Debug', category: LogCategory.system);
      Log.info('  ID: ${video.id.substring(0, 8)}...', name: 'Debug', category: LogCategory.system);
      Log.info('  Title: ${video.title ?? "No title"}', name: 'Debug', category: LogCategory.system);
      Log.info('  Video URL: ${video.videoUrl ?? "No URL"}', name: 'Debug', category: LogCategory.system);
      Log.info('  Has Video: ${video.hasVideo}', name: 'Debug', category: LogCategory.system);
      Log.info('  Created: ${video.timestamp}', name: 'Debug', category: LogCategory.system);
    }
    
    // Now check Editor's Picks from CurationService
    Log.info('\n📋 Checking Editor\'s Picks from CurationService...', name: 'Debug', category: LogCategory.system);
    final editorsPicks = curationService.getVideosForSetType(CurationSetType.editorsPicks);
    Log.info('Editor\'s Picks count: ${editorsPicks.length}', name: 'Debug', category: LogCategory.system);
    
    // Print Editor's Picks details
    for (int i = 0; i < editorsPicks.length && i < 5; i++) {
      final video = editorsPicks[i];
      Log.info('Editor\'s Pick ${i + 1}:', name: 'Debug', category: LogCategory.system);
      Log.info('  ID: ${video.id.substring(0, 8)}...', name: 'Debug', category: LogCategory.system);
      Log.info('  Title: ${video.title ?? "No title"}', name: 'Debug', category: LogCategory.system);
      Log.info('  Pubkey: ${video.pubkey.substring(0, 8)}...', name: 'Debug', category: LogCategory.system);
      Log.info('  Is Classic Vine: ${video.pubkey == AppConstants.classicVinesPubkey}', name: 'Debug', category: LogCategory.system);
    }
    
    // Check if Editor's Picks is using default video
    if (editorsPicks.isNotEmpty && editorsPicks.first.id == 'default-intro-video-001') {
      Log.warning('⚠️ Editor\'s Picks is showing default video instead of Classic Vines content', name: 'Debug', category: LogCategory.system);
    }
    
  } catch (e, stackTrace) {
    Log.error('Test failed with error: $e', name: 'Debug', category: LogCategory.system);
    Log.error('Stack trace: $stackTrace', name: 'Debug', category: LogCategory.system);
  } finally {
    // Cleanup
    await videoEventService.unsubscribeFromVideoFeed();
    await nostrService.close();
    Log.info('Test completed', name: 'Debug', category: LogCategory.system);
  }
}