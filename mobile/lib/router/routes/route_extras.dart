// ABOUTME: Extra data classes for GoRouter navigation
// ABOUTME: Used to pass structured data between routes via GoRouter extra

/// Extra data for curated list route (passed via GoRouter extra)
class CuratedListRouteExtra {
  const CuratedListRouteExtra({
    required this.listName,
    this.videoIds,
    this.authorPubkey,
  });

  final String listName;
  final List<String>? videoIds;
  final String? authorPubkey;
}

/// Extra data for video editor route (passed via GoRouter extra)
class VideoEditorRouteExtra {
  const VideoEditorRouteExtra({
    required this.videoPath,
    this.externalAudioEventId,
    this.externalAudioUrl,
    this.externalAudioIsBundled = false,
    this.externalAudioAssetPath,
  });

  final String videoPath;
  final String? externalAudioEventId;
  final String? externalAudioUrl;
  final bool externalAudioIsBundled;
  final String? externalAudioAssetPath;
}
