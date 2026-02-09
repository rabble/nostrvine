// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_realtime_bridge_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Bridge that listens to WebSocket notifications from
/// [NotificationServiceEnhanced] and inserts them into the
/// REST-based [RelayNotifications] provider for instant UI updates.
///
/// This provider is kept alive so it runs in the background as long as
/// the app is active.

@ProviderFor(NotificationRealtimeBridge)
const notificationRealtimeBridgeProvider =
    NotificationRealtimeBridgeProvider._();

/// Bridge that listens to WebSocket notifications from
/// [NotificationServiceEnhanced] and inserts them into the
/// REST-based [RelayNotifications] provider for instant UI updates.
///
/// This provider is kept alive so it runs in the background as long as
/// the app is active.
final class NotificationRealtimeBridgeProvider
    extends $NotifierProvider<NotificationRealtimeBridge, int> {
  /// Bridge that listens to WebSocket notifications from
  /// [NotificationServiceEnhanced] and inserts them into the
  /// REST-based [RelayNotifications] provider for instant UI updates.
  ///
  /// This provider is kept alive so it runs in the background as long as
  /// the app is active.
  const NotificationRealtimeBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationRealtimeBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationRealtimeBridgeHash();

  @$internal
  @override
  NotificationRealtimeBridge create() => NotificationRealtimeBridge();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$notificationRealtimeBridgeHash() =>
    r'af3bbdad5ffe033712b893c7a42d35e461356fee';

/// Bridge that listens to WebSocket notifications from
/// [NotificationServiceEnhanced] and inserts them into the
/// REST-based [RelayNotifications] provider for instant UI updates.
///
/// This provider is kept alive so it runs in the background as long as
/// the app is active.

abstract class _$NotificationRealtimeBridge extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
