// ABOUTME: Script to generate seed data SQL from relay.divine.video
// ABOUTME: Fetches Editor's Picks curation list, top videos by loop count, and downloads media files
//
// USAGE: dart run scripts/generate_seed_data.dart

import 'dart:convert';
import 'dart:io';

const String editorPicksEventId =
    '5e2797304dda04159f8f9f6c36cc5d7f473abe3931f21d7b68fed1ab6a04db3a';
const String relayUrl = 'wss://relay.divine.video';
const int targetVideoCount = 250;
const int maxQueryVideos = 1000;
const int topMediaDownloadCount = 10; // Number of videos/thumbnails to download

Future<void> main() async {
  print('[SEED GEN] Connecting to $relayUrl...');

  try {
    final relay = await NostrRelay.connect(relayUrl);
    print('[SEED GEN] ✅ Connected');

    // Step 1: Fetch Editor's Picks curation list (kind 30005)
    print("[SEED GEN] Fetching Editor's Picks curation list...");
    print('[SEED GEN] Looking for event ID: $editorPicksEventId');

    // Try multiple queries to find the curation list
    var editorPicksEvents = await relay.query({
      'kinds': [30005],
      'ids': [editorPicksEventId],
    });

    // If not found by ID, try querying all kind 30005 events
    if (editorPicksEvents.isEmpty) {
      print(
        '[SEED GEN] Event not found by ID, querying all kind 30005 events...',
      );
      editorPicksEvents = await relay.query({
        'kinds': [30005],
        'limit': 100,
      });
      print(
        '[SEED GEN] Found ${editorPicksEvents.length} kind 30005 events total',
      );

      // Filter for the specific event ID
      editorPicksEvents = editorPicksEvents
          .where((e) => e['id'] == editorPicksEventId)
          .toList();
      if (editorPicksEvents.isNotEmpty) {
        print("[SEED GEN] ✅ Found Editor's Picks in full query results");
      } else {
        // Try to find any "Editor's Picks" by title
        for (final event in editorPicksEvents) {
          final tags = event['tags'] as List;
          for (final tag in tags) {
            if (tag is List &&
                tag.length >= 2 &&
                tag[0].toString() == 'title' &&
                tag[1].toString().toLowerCase().contains('editor')) {
              print("[SEED GEN] ✅ Found Editor's Picks by title match");
              editorPicksEvents = [event];
              break;
            }
          }
          if (editorPicksEvents.length == 1) break;
        }
      }
    }

    Map<String, dynamic>? editorPicksEvent;
    final List<String> editorPicksVideoIds = [];

    if (editorPicksEvents.isNotEmpty) {
      editorPicksEvent = editorPicksEvents.first;
      print(
        "[SEED GEN] ✅ Found Editor's Picks curation list (kind ${editorPicksEvent['kind']})",
      );

      // Parse video IDs from 'a' and 'e' tags
      final tags = editorPicksEvent['tags'] as List;
      for (final tag in tags) {
        if (tag is! List || tag.isEmpty) continue;
        final tagName = tag[0].toString();
        final tagValue = tag.length > 1 ? tag[1].toString() : '';

        if (tagName == 'a') {
          // Addressable reference: "kind:pubkey:d-tag"
          editorPicksVideoIds.add(tagValue);
        } else if (tagName == 'e') {
          // Direct event ID reference
          editorPicksVideoIds.add(tagValue);
        }
      }

      print(
        "[SEED GEN] 📋 Found ${editorPicksVideoIds.length} video references in Editor's Picks",
      );
    } else {
      print("[SEED GEN] ⚠️ WARNING: Editor's Picks list not found!");
      print('[SEED GEN] Will proceed with only top videos by loop count...');
    }

    // Step 2: Fetch Editor's Picks videos (if we have any)
    final List<Map<String, dynamic>> editorPicksVideos = [];
    if (editorPicksVideoIds.isNotEmpty) {
      print("[SEED GEN] Fetching Editor's Picks videos...");

      // Separate direct IDs from addressable references
      final directIds = <String>[];
      final addressableRefs = <String>[];

      for (final id in editorPicksVideoIds) {
        if (id.contains(':')) {
          addressableRefs.add(id);
        } else {
          directIds.add(id);
        }
      }

      // Fetch direct IDs
      if (directIds.isNotEmpty) {
        final directEvents = await relay.query({
          'kinds': [34236, 22],
          'ids': directIds,
        });
        editorPicksVideos.addAll(directEvents);
        print(
          "[SEED GEN] ✅ Fetched ${directEvents.length} direct Editor's Picks videos",
        );
      }

      // For addressable references, we query all videos and filter manually
      // This is a limitation of the simple query approach
      if (addressableRefs.isNotEmpty) {
        print(
          '[SEED GEN] ⚠️ Note: ${addressableRefs.length} addressable references require manual filtering',
        );
      }

      print(
        "[SEED GEN] ✅ Total Editor's Picks videos fetched: ${editorPicksVideos.length}",
      );
    }

    // Step 3: Query for additional popular videos to fill up to target total
    print(
      '[SEED GEN] Need ${targetVideoCount - editorPicksVideos.length} more videos to reach target of $targetVideoCount',
    );
    print('[SEED GEN] Querying for top videos by loop count...');

    final allVideos = await relay.query({
      'kinds': [34236],
      'limit': maxQueryVideos,
    });
    print('[SEED GEN] Found ${allVideos.length} total videos');

    // Filter videos with loop count and sort by loop count descending
    final videosWithLoops = allVideos.where((e) {
      final tags = e['tags'] as List;
      for (final tag in tags) {
        if (tag is List &&
            tag.isNotEmpty &&
            tag.length >= 2 &&
            tag[0].toString() == 'loops') {
          final loopCount = int.tryParse(tag[1].toString());
          return loopCount != null && loopCount > 0;
        }
      }
      return false;
    }).toList();

    print(
      '[SEED GEN] Found ${videosWithLoops.length} videos with loop count > 0',
    );

    videosWithLoops.sort((a, b) {
      int getLoopCount(Map<String, dynamic> event) {
        final tags = event['tags'] as List;
        for (final tag in tags) {
          if (tag is List &&
              tag.isNotEmpty &&
              tag.length >= 2 &&
              tag[0].toString() == 'loops') {
            return int.tryParse(tag[1].toString()) ?? 0;
          }
        }
        return 0;
      }

      return getLoopCount(b).compareTo(getLoopCount(a));
    });

    // Combine Editor's Picks with top popular videos
    final selectedVideos =
        <String, Map<String, dynamic>>{}; // Deduplicate by ID

    // Add Editor's Picks first (priority)
    for (final video in editorPicksVideos) {
      selectedVideos[video['id'] as String] = video;
    }

    // Fill remaining slots with popular videos
    for (final video in videosWithLoops) {
      if (selectedVideos.length >= targetVideoCount) break;
      selectedVideos[video['id'] as String] = video;
    }

    final finalVideos = selectedVideos.values.toList();
    print('[SEED GEN] ✅ Selected ${finalVideos.length} total videos');
    print(
      "[SEED GEN]    - Editor's Picks: ${editorPicksVideos.length} videos",
    );
    print(
      '[SEED GEN]    - Popular videos: ${finalVideos.length - editorPicksVideos.length} videos',
    );

    // Step 4: Extract unique author pubkeys
    final authorPubkeys = finalVideos
        .map((e) => e['pubkey'] as String)
        .toSet()
        .toList();
    print('[SEED GEN] Found ${authorPubkeys.length} unique authors');

    // Step 5: Query for author profiles (kind 0)
    // Batch the queries because querying 196 authors at once might timeout
    print(
      '[SEED GEN] Querying for author profiles (${authorPubkeys.length} authors)...',
    );
    final profileEvents = <Map<String, dynamic>>[];
    const batchSize = 50;

    for (var i = 0; i < authorPubkeys.length; i += batchSize) {
      final batch = authorPubkeys.skip(i).take(batchSize).toList();
      print(
        '[SEED GEN]   Fetching profiles ${i + 1}-${i + batch.length} of ${authorPubkeys.length}...',
      );
      final batchProfiles = await relay.query({
        'kinds': [0],
        'authors': batch,
      }, timeoutSeconds: 20);
      profileEvents.addAll(batchProfiles);
      print(
        '[SEED GEN]   Found ${batchProfiles.length} profiles in this batch',
      );
    }

    print('[SEED GEN] Found ${profileEvents.length} total profiles');

    // Step 6: Generate JSON bundle
    print('[SEED GEN] Generating JSON bundle...');
    final bundle = _generateBundle(
      finalVideos,
      profileEvents,
      editorPicksEvent,
      editorPicksVideos.length,
    );

    // Step 7: Write to file
    final outputFile = File('assets/seed_data/seed_events.json');
    await outputFile.create(recursive: true);
    await outputFile.writeAsString(jsonEncode(bundle));

    final fileSize = await outputFile.length();
    final fileSizeMB = fileSize / (1024 * 1024);

    print('[SEED GEN] ✅ Generated seed data: ${outputFile.path}');
    print('[SEED GEN]    Videos: ${finalVideos.length}');
    print('[SEED GEN]    Profiles: ${profileEvents.length}');
    print('[SEED GEN]    Curation list: ${editorPicksEvent != null ? 1 : 0}');
    print(
      '[SEED GEN]    Total events: ${finalVideos.length + profileEvents.length + (editorPicksEvent != null ? 1 : 0)}',
    );
    print(
      '[SEED GEN]    File size: ${fileSizeMB.toStringAsFixed(2)} MB ($fileSize bytes)',
    );

    // Step 8: Download media files for top videos
    print(
      '\n[SEED GEN] Downloading media files for top $topMediaDownloadCount videos...',
    );
    final mediaResult = await _downloadMediaFiles(
      videosWithLoops.take(topMediaDownloadCount).toList(),
    );

    print('\n[SEED GEN] ✅ Media download complete:');
    print(
      '[SEED GEN]    Videos downloaded: ${mediaResult['videosDownloaded']}/${mediaResult['videosAttempted']}',
    );
    print(
      '[SEED GEN]    Thumbnails downloaded: ${mediaResult['thumbnailsDownloaded']}/${mediaResult['thumbnailsAttempted']}',
    );
    print(
      '[SEED GEN]    Total size: ${(mediaResult['totalSize'] / (1024 * 1024)).toStringAsFixed(2)} MB',
    );
    if ((mediaResult['failures'] as String).isNotEmpty) {
      print(
        '[SEED GEN]    ⚠️ Failed downloads: ${mediaResult['failures'].length}',
      );
      for (final failure in mediaResult['failures'] as List<dynamic>) {
        print('[SEED GEN]       - $failure');
      }
    }

    await relay.close();
  } catch (e, stack) {
    print('[SEED GEN] ❌ Error: $e');
    print('[SEED GEN] Stack: $stack');
    exit(1);
  }
}

Map<String, dynamic> _generateBundle(
  List<Map<String, dynamic>> videos,
  List<Map<String, dynamic>> profiles,
  Map<String, dynamic>? curationList,
  int editorPicksCount,
) {
  final nowIso = DateTime.now().toIso8601String();
  final events = <Map<String, dynamic>>[
    if (curationList != null) _eventJson(curationList),
    ...videos.map(_eventJson),
    ...profiles.map(_eventJson),
  ];
  final profileRows = <Map<String, dynamic>>[];
  for (final profile in profiles) {
    final row = _profileJson(profile, generatedAtIso: nowIso);
    if (row != null) profileRows.add(row);
  }
  final metrics = videos
      .map((v) => _metricsJson(v, updatedAtIso: nowIso))
      .toList();
  return {
    'meta': {
      'generated_at': nowIso,
      'videos': videos.length,
      'editor_picks': editorPicksCount,
      'popular': videos.length - editorPicksCount,
      'profiles': profiles.length,
      'curation_lists': curationList != null ? 1 : 0,
    },
    'events': events,
    'profiles': profileRows,
    'metrics': metrics,
  };
}

Map<String, dynamic> _eventJson(Map<String, dynamic> event) {
  return {
    'id': event['id'],
    'pubkey': event['pubkey'],
    'created_at': event['created_at'],
    'kind': event['kind'],
    'tags': event['tags'],
    'content': event['content'],
    'sig': event['sig'],
  };
}

Map<String, dynamic>? _profileJson(
  Map<String, dynamic> event, {
  required String generatedAtIso,
}) {
  try {
    final profile =
        jsonDecode(event['content'] as String) as Map<String, dynamic>;
    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (event['created_at'] as int) * 1000,
    );
    return {
      'pubkey': event['pubkey'],
      'display_name': profile['display_name'],
      'name': profile['name'],
      'picture': profile['picture'],
      'banner': profile['banner'],
      'about': profile['about'],
      'website': profile['website'],
      'nip05': profile['nip05'],
      'lud16': profile['lud16'],
      'lud06': profile['lud06'],
      'raw_data': event['content'],
      'created_at': createdAt.toIso8601String(),
      'event_id': event['id'],
      'last_fetched': generatedAtIso,
    };
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _metricsJson(
  Map<String, dynamic> event, {
  required String updatedAtIso,
}) {
  final tags = event['tags'] as List;
  return {
    'event_id': event['id'],
    'loop_count': _tagInt(tags, 'loops'),
    'likes': _tagInt(tags, 'likes'),
    'views': _tagInt(tags, 'views'),
    'comments': _tagInt(tags, 'comments'),
    'updated_at': updatedAtIso,
  };
}

int? _tagInt(List tags, String tagName) {
  for (final tag in tags) {
    if (tag is List && tag.length >= 2 && tag[0].toString() == tagName) {
      return int.tryParse(tag[1].toString());
    }
  }
  return null;
}

/// Download media files for top videos
Future<Map<String, dynamic>> _downloadMediaFiles(
  List<Map<String, dynamic>> videos,
) async {
  final videosDir = Directory('assets/seed_media/videos');
  final thumbnailsDir = Directory('assets/seed_media/thumbnails');

  // Create directories
  await videosDir.create(recursive: true);
  await thumbnailsDir.create(recursive: true);

  final manifestData = {
    'videos': <Map<String, dynamic>>[],
    'thumbnails': <Map<String, dynamic>>[],
    'generatedAt': DateTime.now().toIso8601String(),
  };

  var videosDownloaded = 0;
  var thumbnailsDownloaded = 0;
  var videosAttempted = 0;
  var thumbnailsAttempted = 0;
  var totalSize = 0;
  final failures = <String>[];
  final httpClient = HttpClient();

  final videosList = manifestData['videos']! as List<Map<String, dynamic>>;
  final thumbnailsList =
      manifestData['thumbnails']! as List<Map<String, dynamic>>;

  for (var i = 0; i < videos.length; i++) {
    final video = videos[i];
    final eventId = video['id'] as String;
    final tags = video['tags'] as List;

    print(
      '[SEED GEN]   Processing video ${i + 1}/${videos.length} ($eventId)...',
    );

    // Extract video URL and thumbnail from tags
    String? videoUrl;
    String? thumbnailUrl;

    for (final tag in tags) {
      if (tag is! List || tag.isEmpty) continue;
      final tagName = tag[0].toString();

      // Handle imeta tag: ["imeta", "url", "https://...", "m", "video/mp4", ..., "image", "https://..."]
      if (tagName == 'imeta') {
        for (var i = 1; i < tag.length - 1; i++) {
          if (tag[i].toString() == 'url' && i + 1 < tag.length) {
            final url = tag[i + 1].toString();
            if (url.endsWith('.mp4')) {
              videoUrl = url;
            }
          }
          if (tag[i].toString() == 'image' && i + 1 < tag.length) {
            thumbnailUrl = tag[i + 1].toString();
          }
        }
      }
      // Fallback to simple url/thumb tags
      else if (tagName == 'url' && tag.length >= 2) {
        final url = tag[1].toString();
        if (url.endsWith('.mp4')) {
          videoUrl = url;
        }
      } else if ((tagName == 'thumb' || tagName == 'image') &&
          tag.length >= 2) {
        thumbnailUrl = tag[1].toString();
      }
    }

    // Download video
    if (videoUrl != null) {
      videosAttempted++;
      final videoFile = File('${videosDir.path}/$eventId.mp4');

      if (videoFile.existsSync()) {
        print(
          '[SEED GEN]      ✓ Video already exists (${await videoFile.length()} bytes)',
        );
        final fileSize = await videoFile.length();
        totalSize += fileSize;
        videosDownloaded++;
        videosList.add({
          'eventId': eventId,
          'filename': '$eventId.mp4',
          'url': videoUrl,
          'size': fileSize,
        });
      } else {
        try {
          final downloadResult = await _downloadFile(
            httpClient,
            videoUrl,
            videoFile,
          );
          if (downloadResult['success'] == true) {
            videosDownloaded++;
            final size = downloadResult['size'] as int;
            totalSize += size;
            videosList.add({
              'eventId': eventId,
              'filename': '$eventId.mp4',
              'url': videoUrl,
              'size': size,
            });
            print('[SEED GEN]      ✓ Video downloaded ($size bytes)');
          } else {
            failures.add('Video $eventId: ${downloadResult['error']}');
            print(
              '[SEED GEN]      ✗ Video download failed: ${downloadResult['error']}',
            );
          }
        } catch (e) {
          failures.add('Video $eventId: $e');
          print('[SEED GEN]      ✗ Video download error: $e');
        }
      }
    } else {
      print('[SEED GEN]      ⚠️ No video URL found');
    }

    // Download thumbnail
    if (thumbnailUrl != null) {
      thumbnailsAttempted++;
      final ext = thumbnailUrl.endsWith('.jpg')
          ? 'jpg'
          : thumbnailUrl.endsWith('.jpeg')
          ? 'jpeg'
          : thumbnailUrl.endsWith('.png')
          ? 'png'
          : 'jpg';
      final thumbnailFile = File('${thumbnailsDir.path}/$eventId.$ext');

      if (thumbnailFile.existsSync()) {
        print(
          '[SEED GEN]      ✓ Thumbnail already exists (${await thumbnailFile.length()} bytes)',
        );
        final fileSize = await thumbnailFile.length();
        totalSize += fileSize;
        thumbnailsDownloaded++;
        thumbnailsList.add({
          'eventId': eventId,
          'filename': '$eventId.$ext',
          'url': thumbnailUrl,
          'size': fileSize,
        });
      } else {
        try {
          final downloadResult = await _downloadFile(
            httpClient,
            thumbnailUrl,
            thumbnailFile,
          );
          if (downloadResult['success'] == true) {
            thumbnailsDownloaded++;
            final size = downloadResult['size'] as int;
            totalSize += size;
            thumbnailsList.add({
              'eventId': eventId,
              'filename': '$eventId.$ext',
              'url': thumbnailUrl,
              'size': size,
            });
            print('[SEED GEN]      ✓ Thumbnail downloaded ($size bytes)');
          } else {
            failures.add('Thumbnail $eventId: ${downloadResult['error']}');
            print(
              '[SEED GEN]      ✗ Thumbnail download failed: ${downloadResult['error']}',
            );
          }
        } catch (e) {
          failures.add('Thumbnail $eventId: $e');
          print('[SEED GEN]      ✗ Thumbnail download error: $e');
        }
      }
    } else {
      print('[SEED GEN]      ⚠️ No thumbnail URL found');
    }
  }

  httpClient.close();

  // Write manifest file
  final manifestFile = File('assets/seed_media/manifest.json');
  await manifestFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(manifestData),
  );
  print('[SEED GEN]   ✓ Manifest written to ${manifestFile.path}');

  return {
    'videosDownloaded': videosDownloaded,
    'videosAttempted': videosAttempted,
    'thumbnailsDownloaded': thumbnailsDownloaded,
    'thumbnailsAttempted': thumbnailsAttempted,
    'totalSize': totalSize,
    'failures': failures,
  };
}

/// Download a file from URL
Future<Map<String, dynamic>> _downloadFile(
  HttpClient client,
  String url,
  File outputFile,
) async {
  try {
    final uri = Uri.parse(url);
    final request = await client.getUrl(uri);
    final response = await request.close();

    if (response.statusCode != 200) {
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    }

    final bytes = await response.fold<List<int>>(
      <int>[],
      (previous, element) => previous..addAll(element),
    );

    // Verify file size is reasonable
    final size = bytes.length;
    if (size < 100) {
      return {'success': false, 'error': 'File too small ($size bytes)'};
    }

    await outputFile.writeAsBytes(bytes);

    return {'success': true, 'size': size};
  } catch (e) {
    return {'success': false, 'error': e.toString()};
  }
}

/// Simple Nostr relay client using WebSocket
class NostrRelay {
  final WebSocket _socket;
  final Map<String, List<Map<String, dynamic>>> _responses = {};
  int _subCounter = 0;

  NostrRelay._(this._socket) {
    _socket.listen(_handleMessage);
  }

  static Future<NostrRelay> connect(String url) async {
    final socket = await WebSocket.connect(url);
    return NostrRelay._(socket);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as List;
      if (data.isEmpty) return;

      final type = data[0] as String;
      if (type == 'EVENT' && data.length >= 3) {
        final subId = data[1] as String;
        final event = data[2] as Map<String, dynamic>;
        _responses.putIfAbsent(subId, () => []).add(event);
      }
    } catch (e) {
      // Ignore malformed messages
    }
  }

  Future<List<Map<String, dynamic>>> query(
    Map<String, dynamic> filter, {
    int timeoutSeconds = 15,
  }) async {
    final subId = 'sub_${_subCounter++}';
    _responses[subId] = [];

    // Send REQ message
    final reqMessage = jsonEncode(['REQ', subId, filter]);
    _socket.add(reqMessage);

    // Wait for EOSE (or timeout)
    await Future.delayed(Duration(seconds: timeoutSeconds));

    // Send CLOSE message
    final closeMessage = jsonEncode(['CLOSE', subId]);
    _socket.add(closeMessage);

    final results = _responses[subId] ?? [];
    _responses.remove(subId);
    return results;
  }

  Future<void> close() async {
    await _socket.close();
  }
}
