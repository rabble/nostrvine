// ABOUTME: Provides the app's AvatarSvgRepository to avatar widgets
// ABOUTME: Replaces the former top-level global instance (#8618)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/repositories/avatar_svg_repository.dart';

/// The app's [AvatarSvgRepository], which validates remote avatar SVG payloads
/// before `flutter_svg` sees them.
///
/// Replaces the former top-level `defaultAvatarSvgRepository` global (#8618),
/// which no test could swap out. Account-scoped like any other provider: the
/// cache holds only public avatar bytes keyed by URL, so rebuilding it on an
/// account swap costs a refetch and nothing else. The provider owns the HTTP
/// client it hands the repository, so the connection pool closes with the
/// container instead of living for the process.
final avatarSvgRepositoryProvider = Provider<AvatarSvgRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return HttpAvatarSvgRepository(client: client);
});
