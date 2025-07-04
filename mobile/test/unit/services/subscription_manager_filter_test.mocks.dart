// Mocks generated by Mockito 5.4.5 from annotations
// in openvine/test/unit/services/subscription_manager_filter_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;
import 'dart:ui' as _i8;

import 'package:mockito/mockito.dart' as _i1;
import 'package:nostr_sdk/event.dart' as _i5;
import 'package:nostr_sdk/filter.dart' as _i6;
import 'package:openvine/models/nip94_metadata.dart' as _i7;
import 'package:openvine/services/nostr_key_manager.dart' as _i2;
import 'package:openvine/services/nostr_service_interface.dart' as _i3;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeNostrKeyManager_0 extends _i1.SmartFake
    implements _i2.NostrKeyManager {
  _FakeNostrKeyManager_0(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

class _FakeNostrBroadcastResult_1 extends _i1.SmartFake
    implements _i3.NostrBroadcastResult {
  _FakeNostrBroadcastResult_1(
    Object parent,
    Invocation parentInvocation,
  ) : super(
          parent,
          parentInvocation,
        );
}

/// A class which mocks [INostrService].
///
/// See the documentation for Mockito's code generation for more information.
class MockINostrService extends _i1.Mock implements _i3.INostrService {
  MockINostrService() {
    _i1.throwOnMissingStub(this);
  }

  @override
  bool get isInitialized => (super.noSuchMethod(
        Invocation.getter(#isInitialized),
        returnValue: false,
      ) as bool);

  @override
  bool get isDisposed => (super.noSuchMethod(
        Invocation.getter(#isDisposed),
        returnValue: false,
      ) as bool);

  @override
  List<String> get connectedRelays => (super.noSuchMethod(
        Invocation.getter(#connectedRelays),
        returnValue: <String>[],
      ) as List<String>);

  @override
  bool get hasKeys => (super.noSuchMethod(
        Invocation.getter(#hasKeys),
        returnValue: false,
      ) as bool);

  @override
  _i2.NostrKeyManager get keyManager => (super.noSuchMethod(
        Invocation.getter(#keyManager),
        returnValue: _FakeNostrKeyManager_0(
          this,
          Invocation.getter(#keyManager),
        ),
      ) as _i2.NostrKeyManager);

  @override
  int get relayCount => (super.noSuchMethod(
        Invocation.getter(#relayCount),
        returnValue: 0,
      ) as int);

  @override
  int get connectedRelayCount => (super.noSuchMethod(
        Invocation.getter(#connectedRelayCount),
        returnValue: 0,
      ) as int);

  @override
  List<String> get relays => (super.noSuchMethod(
        Invocation.getter(#relays),
        returnValue: <String>[],
      ) as List<String>);

  @override
  Map<String, dynamic> get relayStatuses => (super.noSuchMethod(
        Invocation.getter(#relayStatuses),
        returnValue: <String, dynamic>{},
      ) as Map<String, dynamic>);

  @override
  bool get hasListeners => (super.noSuchMethod(
        Invocation.getter(#hasListeners),
        returnValue: false,
      ) as bool);

  @override
  _i4.Future<void> initialize({List<String>? customRelays}) =>
      (super.noSuchMethod(
        Invocation.method(
          #initialize,
          [],
          {#customRelays: customRelays},
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Stream<_i5.Event> subscribeToEvents({
    required List<_i6.Filter>? filters,
    bool? bypassLimits = false,
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #subscribeToEvents,
          [],
          {
            #filters: filters,
            #bypassLimits: bypassLimits,
          },
        ),
        returnValue: _i4.Stream<_i5.Event>.empty(),
      ) as _i4.Stream<_i5.Event>);

  @override
  _i4.Future<_i3.NostrBroadcastResult> broadcastEvent(_i5.Event? event) =>
      (super.noSuchMethod(
        Invocation.method(
          #broadcastEvent,
          [event],
        ),
        returnValue: _i4.Future<_i3.NostrBroadcastResult>.value(
            _FakeNostrBroadcastResult_1(
          this,
          Invocation.method(
            #broadcastEvent,
            [event],
          ),
        )),
      ) as _i4.Future<_i3.NostrBroadcastResult>);

  @override
  _i4.Future<_i3.NostrBroadcastResult> publishFileMetadata({
    required _i7.NIP94Metadata? metadata,
    required String? content,
    List<String>? hashtags = const [],
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #publishFileMetadata,
          [],
          {
            #metadata: metadata,
            #content: content,
            #hashtags: hashtags,
          },
        ),
        returnValue: _i4.Future<_i3.NostrBroadcastResult>.value(
            _FakeNostrBroadcastResult_1(
          this,
          Invocation.method(
            #publishFileMetadata,
            [],
            {
              #metadata: metadata,
              #content: content,
              #hashtags: hashtags,
            },
          ),
        )),
      ) as _i4.Future<_i3.NostrBroadcastResult>);

  @override
  _i4.Future<_i3.NostrBroadcastResult> publishVideoEvent({
    required String? videoUrl,
    required String? content,
    String? title,
    String? thumbnailUrl,
    int? duration,
    String? dimensions,
    String? mimeType,
    String? sha256,
    int? fileSize,
    List<String>? hashtags = const [],
  }) =>
      (super.noSuchMethod(
        Invocation.method(
          #publishVideoEvent,
          [],
          {
            #videoUrl: videoUrl,
            #content: content,
            #title: title,
            #thumbnailUrl: thumbnailUrl,
            #duration: duration,
            #dimensions: dimensions,
            #mimeType: mimeType,
            #sha256: sha256,
            #fileSize: fileSize,
            #hashtags: hashtags,
          },
        ),
        returnValue: _i4.Future<_i3.NostrBroadcastResult>.value(
            _FakeNostrBroadcastResult_1(
          this,
          Invocation.method(
            #publishVideoEvent,
            [],
            {
              #videoUrl: videoUrl,
              #content: content,
              #title: title,
              #thumbnailUrl: thumbnailUrl,
              #duration: duration,
              #dimensions: dimensions,
              #mimeType: mimeType,
              #sha256: sha256,
              #fileSize: fileSize,
              #hashtags: hashtags,
            },
          ),
        )),
      ) as _i4.Future<_i3.NostrBroadcastResult>);

  @override
  _i4.Future<bool> addRelay(String? relayUrl) => (super.noSuchMethod(
        Invocation.method(
          #addRelay,
          [relayUrl],
        ),
        returnValue: _i4.Future<bool>.value(false),
      ) as _i4.Future<bool>);

  @override
  _i4.Future<void> removeRelay(String? relayUrl) => (super.noSuchMethod(
        Invocation.method(
          #removeRelay,
          [relayUrl],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  Map<String, bool> getRelayStatus() => (super.noSuchMethod(
        Invocation.method(
          #getRelayStatus,
          [],
        ),
        returnValue: <String, bool>{},
      ) as Map<String, bool>);

  @override
  _i4.Future<void> reconnectAll() => (super.noSuchMethod(
        Invocation.method(
          #reconnectAll,
          [],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  _i4.Future<void> closeAllSubscriptions() => (super.noSuchMethod(
        Invocation.method(
          #closeAllSubscriptions,
          [],
        ),
        returnValue: _i4.Future<void>.value(),
        returnValueForMissingStub: _i4.Future<void>.value(),
      ) as _i4.Future<void>);

  @override
  void dispose() => super.noSuchMethod(
        Invocation.method(
          #dispose,
          [],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void addListener(_i8.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #addListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void removeListener(_i8.VoidCallback? listener) => super.noSuchMethod(
        Invocation.method(
          #removeListener,
          [listener],
        ),
        returnValueForMissingStub: null,
      );

  @override
  void notifyListeners() => super.noSuchMethod(
        Invocation.method(
          #notifyListeners,
          [],
        ),
        returnValueForMissingStub: null,
      );
}
