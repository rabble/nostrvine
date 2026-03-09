// ABOUTME: Diagnostic screen for debugging relay connectivity issues
// ABOUTME: Shows relay connection status, network health, Blossom, and FunnelCake API

import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:nostr_client/nostr_client.dart' show RelayState;
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Result for a single FunnelCake API endpoint test
class FunnelCakeEndpointResult {
  FunnelCakeEndpointResult({
    required this.endpoint,
    required this.isSuccess,
    this.latencyMs,
    this.count,
    this.errorMessage,
    this.details,
  });

  final String endpoint;
  final bool isSuccess;
  final int? latencyMs;
  final int? count;
  final String? errorMessage;
  final String? details;
}

/// Comprehensive FunnelCake API test results
class FunnelCakeTestResults {
  FunnelCakeTestResults({required this.apiBaseUrl, required this.endpoints});

  final String apiBaseUrl;
  final List<FunnelCakeEndpointResult> endpoints;

  int get successCount => endpoints.where((e) => e.isSuccess).length;
  int get failCount => endpoints.where((e) => !e.isSuccess).length;
  bool get allSuccess => failCount == 0;

  /// Average response time across successful endpoints
  int get avgLatencyMs {
    final successful = endpoints.where(
      (e) => e.isSuccess && e.latencyMs != null,
    );
    if (successful.isEmpty) return 0;
    final total = successful.fold<int>(0, (sum, e) => sum + e.latencyMs!);
    return total ~/ successful.length;
  }
}

/// Comprehensive diagnostic screen for relay connectivity debugging
class RelayDiagnosticScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'relay-diagnostic';

  /// Path for this route.
  static const path = '/relay-diagnostic';

  const RelayDiagnosticScreen({super.key});

  @override
  ConsumerState<RelayDiagnosticScreen> createState() =>
      _RelayDiagnosticScreenState();
}

class _RelayDiagnosticScreenState extends ConsumerState<RelayDiagnosticScreen> {
  Map<String, dynamic>? _relayStats;
  Map<String, String> _networkTests = {};
  bool _isTestingNetwork = false;
  bool _isRetrying = false;
  DateTime? _lastRefresh;

  // REST endpoint test results
  BlossomHealthCheckResult? _blossomResult;
  FunnelCakeTestResults? _funnelCakeResults;
  bool _isTestingRestEndpoints = false;

  @override
  void initState() {
    super.initState();
    _refreshDiagnostics();
  }

  Future<void> _refreshDiagnostics() async {
    setState(() {
      _lastRefresh = DateTime.now();
    });

    final nostrService = ref.read(nostrServiceProvider);

    // Get relay stats from NostrClient
    try {
      final stats = await nostrService.getRelayStats();
      setState(() {
        _relayStats = stats;
      });

      // Check if there are video events in the database
      if (stats != null && stats['database'] != null) {
        final totalEvents = stats['database']['total_events'] ?? 0;
        Log.info(
          'Relay cache has $totalEvents total events',
          name: 'RelayDiagnostic',
        );

        // Query for video events specifically to see if any exist
        try {
          final videoEvents = await nostrService.queryEvents([
            nostr.Filter(kinds: [34236], limit: 10),
          ]);
          Log.info(
            'Found ${videoEvents.length} video events in relay cache',
            name: 'RelayDiagnostic',
          );
        } catch (e) {
          Log.error(
            'Failed to query video events: $e',
            name: 'RelayDiagnostic',
          );
        }
      }
    } catch (e) {
      Log.error('Failed to get relay stats: $e', name: 'RelayDiagnostic');
    }
  }

  Future<void> _testNetworkConnectivity() async {
    setState(() {
      _isTestingNetwork = true;
      _networkTests = {};
    });

    final nostrService = ref.read(nostrServiceProvider);
    final relays = nostrService.configuredRelays;

    for (final relayUrl in relays) {
      try {
        // Extract hostname from WebSocket URL
        final uri = Uri.parse(relayUrl);
        final host = uri.host;
        // Use default ports if not explicitly specified (uri.port returns 0 if not set)
        final port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);

        Log.info(
          'Testing connectivity to $host:$port (scheme=${uri.scheme})',
          name: 'RelayDiagnostic',
        );

        // Test TCP connection
        final stopwatch = Stopwatch()..start();
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 5),
        );
        stopwatch.stop();
        await socket.close();

        setState(() {
          _networkTests[relayUrl] = 'OK (${stopwatch.elapsedMilliseconds}ms)';
        });

        Log.info(
          '✅ Relay $relayUrl reachable in ${stopwatch.elapsedMilliseconds}ms',
          name: 'RelayDiagnostic',
        );
      } catch (e) {
        setState(() {
          _networkTests[relayUrl] = 'FAILED: $e';
        });

        Log.error('❌ Relay $relayUrl unreachable: $e', name: 'RelayDiagnostic');
      }
    }

    setState(() {
      _isTestingNetwork = false;
    });
  }

  Future<void> _testRestEndpoints() async {
    setState(() {
      _isTestingRestEndpoints = true;
      _blossomResult = null;
      _funnelCakeResults = null;
    });

    Log.info('🔍 Testing REST endpoints...', name: 'RelayDiagnostic');

    // Test Blossom server
    try {
      final blossomService = ref.read(blossomUploadServiceProvider);
      final blossomResult = await blossomService.testServerConnection();
      setState(() {
        _blossomResult = blossomResult;
      });
      Log.info(
        'Blossom server: ${blossomResult.isReachable ? "OK" : "FAILED"} '
        '(${blossomResult.latencyMs}ms)',
        name: 'RelayDiagnostic',
      );
    } catch (e) {
      Log.error('Blossom test error: $e', name: 'RelayDiagnostic');
      setState(() {
        _blossomResult = BlossomHealthCheckResult(
          isReachable: false,
          errorMessage: e.toString(),
        );
      });
    }

    // Test FunnelCake API - comprehensive endpoint testing
    final nostrService = ref.read(nostrServiceProvider);
    final relays = nostrService.configuredRelays;
    if (relays.isNotEmpty) {
      final relayUrl = relays.first;
      final apiBaseUrl = relayUrl
          .replaceFirst('wss://', 'https://')
          .replaceFirst('ws://', 'http://');

      final results = await _testAllFunnelCakeEndpoints(apiBaseUrl);
      setState(() {
        _funnelCakeResults = results;
      });
    } else {
      setState(() {
        _funnelCakeResults = FunnelCakeTestResults(
          apiBaseUrl: 'N/A',
          endpoints: [
            FunnelCakeEndpointResult(
              endpoint: 'N/A',
              isSuccess: false,
              errorMessage: 'No relays configured',
            ),
          ],
        );
      });
    }

    setState(() {
      _isTestingRestEndpoints = false;
    });

    if (mounted) {
      final blossomOk = _blossomResult?.isReachable ?? false;
      final funnelCakeOk = _funnelCakeResults?.allSuccess ?? false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            blossomOk && funnelCakeOk
                ? 'All REST endpoints healthy!'
                : 'Some REST endpoints failed - see details above',
          ),
          backgroundColor: blossomOk && funnelCakeOk
              ? VineTheme.success
              : VineTheme.warning,
        ),
      );
    }
  }

  Future<FunnelCakeTestResults> _testAllFunnelCakeEndpoints(
    String apiBaseUrl,
  ) async {
    final endpoints = <FunnelCakeEndpointResult>[];

    // Test /api/stats
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/stats', (json) {
        final totalVideos = json['total_videos'] as int?;
        final totalEvents = json['total_events'] as int?;
        return (
          count: totalVideos,
          details: '$totalEvents events, $totalVideos videos',
        );
      }),
    );

    // Test /api/videos
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/videos?limit=5', (json) {
        final list = json as List;
        return (count: list.length, details: 'returned ${list.length}');
      }),
    );

    // Test /api/videos/events (with full Nostr events)
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/videos/events?limit=5', (
        json,
      ) {
        final videos = json['videos'] as List?;
        final hasMore = json['has_more'] as bool?;
        return (
          count: videos?.length,
          details: '${videos?.length ?? 0} events, hasMore=$hasMore',
        );
      }),
    );

    // Test /api/videos?sort=trending
    endpoints.add(
      await _testFunnelCakeEndpoint(
        apiBaseUrl,
        '/api/videos?sort=trending&limit=5',
        (json) {
          final list = json as List;
          return (count: list.length, details: '${list.length} trending');
        },
      ),
    );

    // Test /api/hashtags
    endpoints.add(
      await _testFunnelCakeEndpoint(apiBaseUrl, '/api/hashtags?limit=5', (
        json,
      ) {
        final list = json as List;
        final topTag = list.isNotEmpty ? list[0]['hashtag'] : 'none';
        return (count: list.length, details: 'top: #$topTag');
      }),
    );

    // Test /api/hashtags/trending
    endpoints.add(
      await _testFunnelCakeEndpoint(
        apiBaseUrl,
        '/api/hashtags/trending?limit=5',
        (json) {
          final list = json as List;
          return (count: list.length, details: '${list.length} trending tags');
        },
      ),
    );

    return FunnelCakeTestResults(apiBaseUrl: apiBaseUrl, endpoints: endpoints);
  }

  Future<FunnelCakeEndpointResult> _testFunnelCakeEndpoint(
    String apiBaseUrl,
    String path,
    ({int? count, String? details}) Function(dynamic json) parseResponse,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await http
          .get(Uri.parse('$apiBaseUrl$path'))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();

      if (response.statusCode == 200) {
        try {
          final json = response.body.isNotEmpty
              ? _parseJson(response.body)
              : null;
          final parsed = json != null
              ? parseResponse(json)
              : (count: null, details: null);
          return FunnelCakeEndpointResult(
            endpoint: path.split('?').first,
            isSuccess: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            count: parsed.count,
            details: parsed.details,
          );
        } catch (e) {
          return FunnelCakeEndpointResult(
            endpoint: path.split('?').first,
            isSuccess: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            details: 'Parse error: $e',
          );
        }
      } else {
        return FunnelCakeEndpointResult(
          endpoint: path.split('?').first,
          isSuccess: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          errorMessage: 'HTTP ${response.statusCode}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return FunnelCakeEndpointResult(
        endpoint: path.split('?').first,
        isSuccess: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorMessage: e.toString().length > 50
            ? '${e.toString().substring(0, 50)}...'
            : e.toString(),
      );
    }
  }

  dynamic _parseJson(String body) {
    return body.startsWith('[')
        ? (body.isNotEmpty ? _decodeJsonList(body) : [])
        : (body.isNotEmpty ? _decodeJsonMap(body) : {});
  }

  List<dynamic> _decodeJsonList(String body) {
    return (const JsonDecoder().convert(body)) as List<dynamic>;
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    return (const JsonDecoder().convert(body)) as Map<String, dynamic>;
  }

  Future<void> _testDirectEventQuery() async {
    Log.info(
      '🔍 Testing direct event query (bypassing subscriptions)...',
      name: 'RelayDiagnostic',
    );

    final nostrService = ref.read(nostrServiceProvider);

    try {
      // Query for video events directly from relay
      final videoEvents = await nostrService.queryEvents([
        nostr.Filter(kinds: [34236], limit: 100),
      ]);

      Log.info(
        '✅ Direct query returned ${videoEvents.length} video events',
        name: 'RelayDiagnostic',
      );

      if (videoEvents.isNotEmpty) {
        Log.info('📹 Sample events:', name: 'RelayDiagnostic');
        for (var i = 0; i < videoEvents.take(3).length; i++) {
          final event = videoEvents[i];
          Log.info(
            '  Event $i: kind=${event.kind}, author=${event.pubkey}, timestamp=${event.createdAt}',
            name: 'RelayDiagnostic',
          );
        }
      } else {
        Log.warning(
          '⚠️ No video events found in relay cache!',
          name: 'RelayDiagnostic',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${videoEvents.length} video events in database',
            ),
            backgroundColor: videoEvents.isNotEmpty
                ? VineTheme.success
                : VineTheme.warning,
          ),
        );
      }
    } catch (e) {
      Log.error('❌ Direct query failed: $e', name: 'RelayDiagnostic');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Query failed: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _retryConnection() async {
    setState(() {
      _isRetrying = true;
    });

    try {
      final nostrService = ref.read(nostrServiceProvider);

      Log.info('Retrying relay connections...', name: 'RelayDiagnostic');

      await nostrService.retryDisconnectedRelays();

      // Wait a bit for connections to establish
      await Future.delayed(const Duration(seconds: 2));

      // Refresh diagnostics
      await _refreshDiagnostics();

      // Check if any relays connected
      final connectedCount = nostrService.connectedRelayCount;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              connectedCount > 0
                  ? 'Connected to $connectedCount relay(s)!'
                  : 'Failed to connect to any relays',
            ),
            backgroundColor: connectedCount > 0
                ? VineTheme.success
                : VineTheme.error,
          ),
        );
      }

      // Trigger feed refresh if connected
      if (connectedCount > 0) {
        final videoService = ref.read(videoEventServiceProvider);
        await videoService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
      }
    } catch (e) {
      Log.error('Failed to retry connection: $e', name: 'RelayDiagnostic');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection retry failed: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nostrService = ref.watch(nostrServiceProvider);
    final videoService = ref.watch(videoEventServiceProvider);

    final configuredRelays = nostrService.configuredRelays;
    final connectedRelays = nostrService.connectedRelays;
    final relayStatuses = nostrService.relayStatuses;

    // Count events in different feeds
    final homeFeedCount = videoService.homeFeedVideos.length;
    final discoveryCount = videoService.discoveryVideos.length;

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: DiVineAppBar(
        title: 'Relay Diagnostics',
        showBackButton: true,
        onBackPressed: context.pop,
        actions: [
          DiVineAppBarAction(
            icon: const SvgIconSource('assets/icon/ArrowClockwise.svg'),
            onPressed: _refreshDiagnostics,
            tooltip: 'Refresh diagnostics',
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Last refresh time
              if (_lastRefresh != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Last refresh: ${_formatTime(_lastRefresh!)}',
                    style: const TextStyle(
                      color: VineTheme.lightText,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Relay status
              _buildSection(
                title: 'Relay Status',
                icon: Icons.storage,
                children: [
                  _buildStatusRow(
                    'Initialized',
                    nostrService.isInitialized,
                    nostrService.isInitialized ? 'Ready' : 'Not initialized',
                  ),
                  if (_relayStats != null) ...[
                    _buildInfoRow(
                      'Database Events',
                      _relayStats!['database']?['total_events']?.toString() ??
                          'N/A',
                    ),
                    _buildInfoRow(
                      'Active Subscriptions',
                      _relayStats!['subscriptions']?['active_count']
                              ?.toString() ??
                          'N/A',
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // External relays status
              _buildSection(
                title: 'External Relays',
                icon: Icons.cloud,
                children: [
                  _buildInfoRow(
                    'Configured',
                    '${configuredRelays.length} relay(s)',
                  ),
                  _buildInfoRow(
                    'Connected',
                    '${connectedRelays.length}/${configuredRelays.length}',
                  ),
                  const Divider(color: VineTheme.lightText),
                  ...configuredRelays.map((relayUrl) {
                    final isConnected = connectedRelays.contains(relayUrl);
                    final status = relayStatuses[relayUrl];
                    final isAuthenticated =
                        status?.state == RelayState.authenticated;
                    return _buildRelayRow(
                      relayUrl,
                      isConnected,
                      isAuthenticated,
                    );
                  }),
                ],
              ),

              const SizedBox(height: 16),

              // Video events status
              _buildSection(
                title: 'Video Events',
                icon: Icons.video_library,
                children: [
                  _buildInfoRow('Home Feed', '$homeFeedCount videos'),
                  _buildInfoRow('Discovery', '$discoveryCount videos'),
                  _buildInfoRow(
                    'Loading',
                    videoService.isLoading ? 'Yes' : 'No',
                  ),
                  if (videoService.error != null)
                    _buildErrorRow('Error', videoService.error!),
                  const Divider(color: VineTheme.lightText),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _testDirectEventQuery,
                      icon: const Icon(
                        Icons.search,
                        color: VineTheme.whiteText,
                      ),
                      label: const Text(
                        'Test Direct Query',
                        style: TextStyle(color: VineTheme.whiteText),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VineTheme.vineGreen,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Network connectivity test
              _buildSection(
                title: 'Network Connectivity',
                icon: Icons.network_check,
                children: [
                  if (_networkTests.isEmpty && !_isTestingNetwork)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _testNetworkConnectivity,
                        icon: const Icon(
                          Icons.play_arrow,
                          color: VineTheme.whiteText,
                        ),
                        label: const Text(
                          'Run Network Test',
                          style: TextStyle(color: VineTheme.whiteText),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                        ),
                      ),
                    ),
                  if (_isTestingNetwork)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            VineTheme.vineGreen,
                          ),
                        ),
                      ),
                    ),
                  if (_networkTests.isNotEmpty)
                    ..._networkTests.entries.map((entry) {
                      final isOk = entry.value.startsWith('OK');
                      return _buildInfoRow(
                        entry.key,
                        entry.value,
                        textColor: isOk ? VineTheme.success : VineTheme.error,
                      );
                    }),
                ],
              ),

              const SizedBox(height: 16),

              // Blossom Server status
              _buildSection(
                title: 'Blossom Server',
                icon: Icons.cloud_upload,
                children: [
                  if (_blossomResult == null && !_isTestingRestEndpoints)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _testRestEndpoints,
                        icon: const Icon(
                          Icons.play_arrow,
                          color: VineTheme.whiteText,
                        ),
                        label: const Text(
                          'Test All Endpoints',
                          style: TextStyle(color: VineTheme.whiteText),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                        ),
                      ),
                    ),
                  if (_isTestingRestEndpoints && _blossomResult == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            VineTheme.vineGreen,
                          ),
                        ),
                      ),
                    ),
                  if (_blossomResult != null) ...[
                    _buildInfoRow(
                      'Status',
                      _blossomResult!.isReachable
                          ? 'OK (${_blossomResult!.latencyMs}ms)'
                          : 'FAILED',
                      textColor: _blossomResult!.isReachable
                          ? VineTheme.success
                          : VineTheme.error,
                    ),
                    if (_blossomResult!.serverUrl != null)
                      _buildInfoRow('URL', _blossomResult!.serverUrl!),
                    if (_blossomResult!.errorMessage != null)
                      _buildErrorRow('Error', _blossomResult!.errorMessage!),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // FunnelCake API status - comprehensive endpoint testing
              _buildSection(
                title: 'FunnelCake API',
                icon: Icons.api,
                children: [
                  if (_funnelCakeResults == null && !_isTestingRestEndpoints)
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _testRestEndpoints,
                        icon: const Icon(
                          Icons.play_arrow,
                          color: VineTheme.whiteText,
                        ),
                        label: const Text(
                          'Test All Endpoints',
                          style: TextStyle(color: VineTheme.whiteText),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                        ),
                      ),
                    ),
                  if (_isTestingRestEndpoints && _funnelCakeResults == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            VineTheme.vineGreen,
                          ),
                        ),
                      ),
                    ),
                  if (_funnelCakeResults != null) ...[
                    // Summary row
                    _buildInfoRow('Base URL', _funnelCakeResults!.apiBaseUrl),
                    _buildInfoRow(
                      'Summary',
                      '${_funnelCakeResults!.successCount}/${_funnelCakeResults!.endpoints.length} OK '
                          '(avg ${_funnelCakeResults!.avgLatencyMs}ms)',
                      textColor: _funnelCakeResults!.allSuccess
                          ? VineTheme.success
                          : VineTheme.warning,
                    ),
                    const Divider(color: VineTheme.lightText),
                    // Individual endpoint results
                    ..._funnelCakeResults!.endpoints.map(
                      _buildEndpointResultRow,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _testRestEndpoints,
                        child: const Text(
                          'Retest All',
                          style: TextStyle(color: VineTheme.vineGreen),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Retry connection button
              ElevatedButton.icon(
                onPressed: _isRetrying ? null : _retryConnection,
                icon: _isRetrying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            VineTheme.whiteText,
                          ),
                        ),
                      )
                    : const Icon(Icons.refresh, color: VineTheme.whiteText),
                label: Text(
                  _isRetrying ? 'Retrying...' : 'Retry Connection',
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),

              const SizedBox(height: 16),

              // Instructions
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VineTheme.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: VineTheme.secondaryText,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Troubleshooting',
                          style: TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Green status = Connected and working\n'
                      '• Red status = Connection failed\n'
                      '• If network test fails, check internet connection\n'
                      '• If relays are configured but not connected, tap "Retry Connection"\n'
                      '• Screenshot this screen for debugging',
                      style: TextStyle(
                        color: VineTheme.lightText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: VineTheme.vineGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: VineTheme.lightText),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isOk, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : Icons.error,
            color: isOk ? VineTheme.success : VineTheme.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: VineTheme.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isOk ? VineTheme.success : VineTheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: VineTheme.onSurfaceVariant),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: textColor ?? VineTheme.whiteText,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRow(String label, String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: VineTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.errorContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              error,
              style: const TextStyle(color: VineTheme.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndpointResultRow(FunnelCakeEndpointResult result) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.isSuccess ? Icons.check_circle : Icons.error,
            color: result.isSuccess ? VineTheme.success : VineTheme.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.endpoint,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 2),
                if (result.isSuccess)
                  Text(
                    '${result.latencyMs}ms${result.details != null ? ' • ${result.details}' : ''}',
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 11,
                    ),
                  )
                else
                  Text(
                    result.errorMessage ?? 'Failed',
                    style: const TextStyle(
                      color: VineTheme.error,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (result.count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: VineTheme.vineGreen.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${result.count}',
                style: const TextStyle(
                  color: VineTheme.vineGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRelayRow(
    String relayUrl,
    bool isConnected,
    bool isAuthenticated,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isConnected ? Icons.cloud_done : Icons.cloud_off,
                color: isConnected ? VineTheme.success : VineTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  relayUrl,
                  style: const TextStyle(color: VineTheme.whiteText),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              isConnected
                  ? (isAuthenticated
                        ? 'Connected & Authenticated'
                        : 'Connected')
                  : 'Not connected',
              style: TextStyle(
                color: isConnected ? VineTheme.success : VineTheme.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
