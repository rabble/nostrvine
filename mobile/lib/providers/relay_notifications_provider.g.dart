// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relay_notifications_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for relay-based notifications with REST API pagination
///
/// Uses Divine Relay's notifications API for:
/// - Server-side filtering (only events targeting current user)
/// - Cursor-based pagination with has_more
/// - Server-side unread count tracking
/// - Server-side mark-as-read persistence
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose

@ProviderFor(RelayNotifications)
const relayNotificationsProvider = RelayNotificationsProvider._();

/// Provider for relay-based notifications with REST API pagination
///
/// Uses Divine Relay's notifications API for:
/// - Server-side filtering (only events targeting current user)
/// - Cursor-based pagination with has_more
/// - Server-side unread count tracking
/// - Server-side mark-as-read persistence
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose
final class RelayNotificationsProvider
    extends $AsyncNotifierProvider<RelayNotifications, NotificationFeedState> {
  /// Provider for relay-based notifications with REST API pagination
  ///
  /// Uses Divine Relay's notifications API for:
  /// - Server-side filtering (only events targeting current user)
  /// - Cursor-based pagination with has_more
  /// - Server-side unread count tracking
  /// - Server-side mark-as-read persistence
  ///
  /// Timer lifecycle:
  /// - Starts when provider is first watched
  /// - Pauses when all listeners detach (ref.onCancel)
  /// - Resumes when a new listener attaches (ref.onResume)
  /// - Cancels on dispose
  const RelayNotificationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayNotificationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayNotificationsHash();

  @$internal
  @override
  RelayNotifications create() => RelayNotifications();
}

String _$relayNotificationsHash() =>
    r'950fb2281aaf55e4dd4aa6ae48d90e202282718e';

/// Provider for relay-based notifications with REST API pagination
///
/// Uses Divine Relay's notifications API for:
/// - Server-side filtering (only events targeting current user)
/// - Cursor-based pagination with has_more
/// - Server-side unread count tracking
/// - Server-side mark-as-read persistence
///
/// Timer lifecycle:
/// - Starts when provider is first watched
/// - Pauses when all listeners detach (ref.onCancel)
/// - Resumes when a new listener attaches (ref.onResume)
/// - Cancels on dispose

abstract class _$RelayNotifications
    extends $AsyncNotifier<NotificationFeedState> {
  FutureOr<NotificationFeedState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<NotificationFeedState>, NotificationFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<NotificationFeedState>,
                NotificationFeedState
              >,
              AsyncValue<NotificationFeedState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for relay notification API service

@ProviderFor(relayNotificationApiService)
const relayNotificationApiServiceProvider =
    RelayNotificationApiServiceProvider._();

/// Provider for relay notification API service

final class RelayNotificationApiServiceProvider
    extends
        $FunctionalProvider<
          RelayNotificationApiService,
          RelayNotificationApiService,
          RelayNotificationApiService
        >
    with $Provider<RelayNotificationApiService> {
  /// Provider for relay notification API service
  const RelayNotificationApiServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayNotificationApiServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayNotificationApiServiceHash();

  @$internal
  @override
  $ProviderElement<RelayNotificationApiService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RelayNotificationApiService create(Ref ref) {
    return relayNotificationApiService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RelayNotificationApiService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RelayNotificationApiService>(value),
    );
  }
}

String _$relayNotificationApiServiceHash() =>
    r'8df75ff03a5603d7766269c738ed089f407853f4';

/// Provider to get current unread notification count

@ProviderFor(relayNotificationUnreadCount)
const relayNotificationUnreadCountProvider =
    RelayNotificationUnreadCountProvider._();

/// Provider to get current unread notification count

final class RelayNotificationUnreadCountProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  /// Provider to get current unread notification count
  const RelayNotificationUnreadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayNotificationUnreadCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayNotificationUnreadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return relayNotificationUnreadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$relayNotificationUnreadCountHash() =>
    r'ef90b461acd34548961a32c49924d10e62764927';

/// Provider to check if notifications are loading

@ProviderFor(relayNotificationsLoading)
const relayNotificationsLoadingProvider = RelayNotificationsLoadingProvider._();

/// Provider to check if notifications are loading

final class RelayNotificationsLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if notifications are loading
  const RelayNotificationsLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayNotificationsLoadingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayNotificationsLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return relayNotificationsLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$relayNotificationsLoadingHash() =>
    r'6dbafbb77abca10ee0e84310a5a97641c321fa69';

/// Provider to get notifications filtered by type.
///
/// Results are sorted by timestamp (newest first).

@ProviderFor(relayNotificationsByType)
const relayNotificationsByTypeProvider = RelayNotificationsByTypeFamily._();

/// Provider to get notifications filtered by type.
///
/// Results are sorted by timestamp (newest first).

final class RelayNotificationsByTypeProvider
    extends
        $FunctionalProvider<
          List<NotificationModel>,
          List<NotificationModel>,
          List<NotificationModel>
        >
    with $Provider<List<NotificationModel>> {
  /// Provider to get notifications filtered by type.
  ///
  /// Results are sorted by timestamp (newest first).
  const RelayNotificationsByTypeProvider._({
    required RelayNotificationsByTypeFamily super.from,
    required NotificationType? super.argument,
  }) : super(
         retry: null,
         name: r'relayNotificationsByTypeProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$relayNotificationsByTypeHash();

  @override
  String toString() {
    return r'relayNotificationsByTypeProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<List<NotificationModel>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<NotificationModel> create(Ref ref) {
    final argument = this.argument as NotificationType?;
    return relayNotificationsByType(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<NotificationModel> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<NotificationModel>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RelayNotificationsByTypeProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$relayNotificationsByTypeHash() =>
    r'13c8dced839d456ca845419081916dcd46c059bc';

/// Provider to get notifications filtered by type.
///
/// Results are sorted by timestamp (newest first).

final class RelayNotificationsByTypeFamily extends $Family
    with $FunctionalFamilyOverride<List<NotificationModel>, NotificationType?> {
  const RelayNotificationsByTypeFamily._()
    : super(
        retry: null,
        name: r'relayNotificationsByTypeProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Provider to get notifications filtered by type.
  ///
  /// Results are sorted by timestamp (newest first).

  RelayNotificationsByTypeProvider call(NotificationType? type) =>
      RelayNotificationsByTypeProvider._(argument: type, from: this);

  @override
  String toString() => r'relayNotificationsByTypeProvider';
}
