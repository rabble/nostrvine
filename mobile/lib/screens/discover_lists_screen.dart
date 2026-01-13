// ABOUTME: Screen for discovering and subscribing to public curated lists from Nostr relays
// ABOUTME: Shows public kind 30005 video lists with subscribe/unsubscribe functionality

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/user_name.dart';

class DiscoverListsScreen extends ConsumerStatefulWidget {
  const DiscoverListsScreen({super.key});

  static const String path = '/discover-lists';

  static const String routeName = 'discover-lists';

  @override
  ConsumerState<DiscoverListsScreen> createState() =>
      _DiscoverListsScreenState();
}

class _DiscoverListsScreenState extends ConsumerState<DiscoverListsScreen> {
  bool _isLoadingMore = false;
  String? _errorMessage;
  StreamSubscription<List<CuratedList>>? _subscription;
  final _scrollController = ScrollController();

  // Debounce timer for batching rapid stream updates
  Timer? _updateDebounceTimer;
  List<CuratedList>? _pendingLists;

  /// Track if we're in refresh mode (need to merge lists, not replace)
  bool _isRefreshing = false;

  /// Track auto-pagination attempts to avoid infinite loops
  int _autoPaginationAttempts = 0;
  static const int _maxAutoPaginationAttempts = 5;
  static const int _minListsBeforeAutoPaginate = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Check if we already have cached lists from provider
    // Only stream if cache is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cachedState = ref.read(discoveredListsProvider);
      if (cachedState.lists.isEmpty) {
        _streamPublicLists();
      }
    });
  }

  @override
  void dispose() {
    _updateDebounceTimer?.cancel();
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when near bottom
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreLists();
    }
  }

  Future<void> _streamPublicLists({bool isRefresh = false}) async {
    final provider = ref.read(discoveredListsProvider.notifier);
    final currentState = ref.read(discoveredListsProvider);

    // Preserve existing lists during refresh
    final hadExistingLists = currentState.lists.isNotEmpty;

    setState(() {
      _errorMessage = null;
      _isRefreshing = isRefresh;
      _autoPaginationAttempts = 0;
    });

    // Set loading state in provider
    provider.setLoading(!hadExistingLists);

    // Clear lists only if not refreshing
    if (!isRefresh) {
      provider.clear();
    }

    try {
      final service = await ref
          .read(curatedListsStateProvider.notifier)
          .service;

      if (service == null) {
        provider.setLoading(false);
        setState(() {
          _errorMessage = 'Service not available';
        });
        return;
      }

      // Stream results - UI updates with debouncing to handle rapid events
      _subscription?.cancel();
      _subscription = service.streamPublicListsFromRelays().listen(
        (lists) {
          if (mounted) {
            // Track oldest timestamp for pagination
            for (final list in lists) {
              provider.updateOldestTimestamp(list.createdAt);
            }

            // Store pending lists and debounce UI updates
            _pendingLists = lists;

            // Log progress for debugging
            Log.debug(
              '📋 UI received ${lists.length} lists from stream',
              category: LogCategory.ui,
            );

            // Cancel any pending update and schedule a new one
            _updateDebounceTimer?.cancel();
            _updateDebounceTimer = Timer(const Duration(milliseconds: 100), () {
              if (mounted && _pendingLists != null) {
                final newLists = _pendingLists!;

                // During refresh, merge new lists with existing
                if (_isRefreshing) {
                  provider.addLists(newLists);
                  Log.info(
                    '📋 Refresh: merging ${newLists.length} lists',
                    category: LogCategory.ui,
                  );
                } else {
                  provider.setLists(newLists);
                }

                provider.setLoading(false);
                setState(() {
                  _isRefreshing = false;
                });

                // Auto-paginate if we have few results
                final providerState = ref.read(discoveredListsProvider);
                if (providerState.lists.length < _minListsBeforeAutoPaginate &&
                    providerState.oldestTimestamp != null &&
                    _autoPaginationAttempts < _maxAutoPaginationAttempts &&
                    !_isLoadingMore) {
                  _autoPaginationAttempts++;
                  Log.info(
                    'Auto-paginating to find more lists (attempt '
                    '$_autoPaginationAttempts/$_maxAutoPaginationAttempts, '
                    'currently have ${providerState.lists.length} lists)',
                    category: LogCategory.ui,
                  );
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted && !_isLoadingMore) {
                      _loadMoreLists();
                    }
                  });
                }
              }
            });
          }
        },
        onError: (error) {
          if (mounted) {
            provider.setLoading(false);
            setState(() {
              _errorMessage = 'Failed to load lists: $error';
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ref.read(discoveredListsProvider.notifier).setLoading(false);
        setState(() {
          _errorMessage = 'Failed to load lists: $e';
        });
        Log.error(
          'Failed to discover public lists: $e',
          category: LogCategory.ui,
        );
      }
    }
  }

  Future<void> _loadMoreLists() async {
    final providerState = ref.read(discoveredListsProvider);
    if (_isLoadingMore || providerState.oldestTimestamp == null) return;

    setState(() {
      _isLoadingMore = true;
    });

    StreamSubscription<List<CuratedList>>? subscription;
    Timer? timeoutTimer;

    try {
      final service = await ref
          .read(curatedListsStateProvider.notifier)
          .service;

      if (service == null) return;

      final provider = ref.read(discoveredListsProvider.notifier);
      final currentLists = ref.read(discoveredListsProvider).lists;
      final existingIds = currentLists.map((l) => l.id).toSet();
      final initialCount = existingIds.length;

      Log.info(
        '📋 Loading more lists, excluding $initialCount known IDs',
        category: LogCategory.ui,
      );

      final completer = Completer<void>();

      // Stop after 3 seconds
      timeoutTimer = Timer(const Duration(seconds: 3), () {
        Log.info(
          '📋 Pagination timeout - found ${existingIds.length - initialCount} new lists',
          category: LogCategory.ui,
        );
        subscription?.cancel();
        if (!completer.isCompleted) completer.complete();
      });

      final stream = service.streamPublicListsFromRelays(
        until: providerState.oldestTimestamp,
        excludeIds: existingIds,
      );

      subscription = stream.listen(
        (lists) {
          if (!mounted) return;

          // Add new lists that we don't already have
          final newLists = lists
              .where((l) => !existingIds.contains(l.id))
              .toList();

          if (newLists.isNotEmpty) {
            for (final list in newLists) {
              existingIds.add(list.id);
              // Update oldest timestamp in provider
              provider.updateOldestTimestamp(list.createdAt);
            }

            // Add to provider (handles deduplication and sorting)
            provider.addLists(newLists);
          }
        },
        onError: (error) {
          Log.error('Pagination error: $error', category: LogCategory.ui);
          if (!completer.isCompleted) completer.complete();
        },
      );

      await completer.future;

      final finalState = ref.read(discoveredListsProvider);
      Log.info(
        'Pagination done: ${finalState.lists.length} total lists',
        category: LogCategory.ui,
      );
    } finally {
      timeoutTimer?.cancel();
      await subscription?.cancel();
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });

        // Continue auto-paginating if we still have few results
        final finalState = ref.read(discoveredListsProvider);
        if (finalState.lists.length < _minListsBeforeAutoPaginate &&
            finalState.oldestTimestamp != null &&
            _autoPaginationAttempts < _maxAutoPaginationAttempts) {
          _autoPaginationAttempts++;
          Log.info(
            'Continuing auto-pagination (attempt '
            '$_autoPaginationAttempts/$_maxAutoPaginationAttempts, '
            'have ${finalState.lists.length} lists)',
            category: LogCategory.ui,
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isLoadingMore) {
              _loadMoreLists();
            }
          });
        }
      }
    }
  }

  Future<void> _toggleSubscription(CuratedList list) async {
    try {
      final service = await ref
          .read(curatedListsStateProvider.notifier)
          .service;
      final isSubscribed = service?.isSubscribedToList(list.id) ?? false;

      if (isSubscribed) {
        await service?.unsubscribeFromList(list.id);
        Log.info(
          'Unsubscribed from list: ${list.name}',
          category: LogCategory.ui,
        );
      } else {
        await service?.subscribeToList(list.id, list);
        Log.info('Subscribed to list: ${list.name}', category: LogCategory.ui);
      }

      // Trigger rebuild to update button state
      setState(() {});

      // Invalidate providers so Lists tab updates
      ref.invalidate(curatedListsProvider);
    } catch (e) {
      Log.error('Failed to toggle subscription: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update subscription: $e'),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.cardBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: context.pop,
        ),
        title: const Text(
          'Discover Lists',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Watch the provider for reactive updates
    final providerState = ref.watch(discoveredListsProvider);
    final discoveredLists = providerState.lists;
    final isLoading = providerState.isLoading;

    if (isLoading && discoveredLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: VineTheme.vineGreen),
            const SizedBox(height: 16),
            Text(
              'Discovering public lists...',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            Text(
              'Failed to load lists',
              style: TextStyle(
                color: VineTheme.likeRed,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _streamPublicLists,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
              ),
            ),
          ],
        ),
      );
    }

    if (discoveredLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: VineTheme.secondaryText),
            const SizedBox(height: 16),
            Text(
              'No public lists found',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new lists',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: VineTheme.vineGreen,
      onRefresh: () => _streamPublicLists(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        // +1 for loading indicator at bottom
        itemCount: discoveredLists.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at bottom
          if (index == discoveredLists.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
            );
          }
          final list = discoveredLists[index];
          return _buildListCard(list);
        },
      ),
    );
  }

  Widget _buildListCard(CuratedList list) {
    // Check subscription status - don't block rendering on service state
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(list.id),
        ) ??
        false;

    return Card(
      color: VineTheme.cardBackground,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () {
          Log.info(
            'Tapped discovered list: ${list.name}',
            category: LogCategory.ui,
          );
          // Stop any playing videos before navigating
          disposeAllVideoControllers(ref);
          context.pushCuratedList(
            listId: list.id,
            listName: list.name,
            videoIds: list.videoEventIds,
            authorPubkey: list.pubkey,
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.video_library,
                    color: VineTheme.vineGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (list.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            list.description!,
                            style: TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Subscribe/Subscribed button
                  ElevatedButton.icon(
                    onPressed: () => _toggleSubscription(list),
                    icon: Icon(
                      isSubscribed ? Icons.check : Icons.add,
                      size: 18,
                    ),
                    label: Text(
                      isSubscribed ? 'Subscribed' : 'Subscribe',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSubscribed
                          ? VineTheme.cardBackground
                          : VineTheme.vineGreen,
                      foregroundColor: isSubscribed
                          ? VineTheme.vineGreen
                          : VineTheme.backgroundColor,
                      side: isSubscribed
                          ? BorderSide(color: VineTheme.vineGreen, width: 1)
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Creator info
                  if (list.pubkey != null) ...[
                    Text(
                      'by ',
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    Flexible(
                      flex: 0,
                      child: UserName.fromPubKey(
                        list.pubkey!,
                        style: TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${list.videoEventIds.length} ${list.videoEventIds.length == 1 ? 'video' : 'videos'}',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  if (list.tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        list.tags.take(3).map((t) => '#$t').join(' '),
                        style: TextStyle(
                          color: VineTheme.vineGreen,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
