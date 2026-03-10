// ABOUTME: Native platform cache config with iOS-optimized timeout and connection settings
// ABOUTME: Uses dart:io HttpClient for fine-grained connection control

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';
import 'package:openvine/services/safe_json_cache_repository.dart';

/// Creates a [Config] for native platforms with custom HTTP settings.
Config createCacheConfig(String key) {
  return Config(
    key,
    stalePeriod: const Duration(days: 7),
    maxNrOfCacheObjects: 200,
    repo: SafeJsonCacheInfoRepository(databaseName: key),
    fileService: _createHttpFileService(),
  );
}

HttpFileService _createHttpFileService() {
  final httpClient = HttpClient();

  httpClient.connectionTimeout = const Duration(seconds: 10);
  httpClient.idleTimeout = const Duration(seconds: 30);
  httpClient.maxConnectionsPerHost = 6;

  if (kDebugMode &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    httpClient.badCertificateCallback = (cert, host, port) => true;
  }

  return HttpFileService(httpClient: IOClient(httpClient));
}
