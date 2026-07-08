import 'package:divine_quick_actions/divine_quick_actions.dart';
import 'package:divine_quick_actions/divine_quick_actions_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Constructed per test: the constructor installs this instance as the
  // channel's incoming-call handler (last one wins process-wide), so a
  // file-level instance loses the handler to any sibling suite that touches
  // DivineQuickActionsPlatform.instance in the merged-isolate bundle.
  late MethodChannelDivineQuickActions platform;
  const channel = MethodChannel('divine_quick_actions');
  final calls = <MethodCall>[];

  setUp(() {
    platform = MethodChannelDivineQuickActions();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          calls.add(methodCall);
          switch (methodCall.method) {
            case 'isSupported':
              return true;
            case 'setActions':
            case 'clearActions':
              return true;
            case 'getActions':
              return <Map<String, Object?>>[
                <String, Object?>{
                  'type': 'record',
                  'title': 'Record',
                  'payload': <String, String>{'source': 'test'},
                },
              ];
            case 'consumeLaunchAction':
              return <String, Object?>{
                'type': 'search',
                'payload': <String, String>{'query': 'nostr'},
              };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('isSupported delegates to native platform', () async {
    expect(await platform.isSupported(), isTrue);
  });

  test('setActions serializes actions for native platform', () async {
    const action = DivineQuickAction(
      type: 'record',
      title: 'Record',
      subtitle: 'Open camera',
      androidIconName: 'ic_record',
      iosIconName: 'video.fill',
      iosIconStyle: DivineQuickActionIosIconStyle.system,
      rank: 1,
      payload: <String, String>{'source': 'shortcut'},
    );

    expect(await platform.setActions(<DivineQuickAction>[action]), isTrue);

    expect(calls.single.method, 'setActions');
    expect(calls.single.arguments, <Map<String, Object?>>[action.toMap()]);
  });

  test('getActions parses native action maps', () async {
    final actions = await platform.getActions();

    expect(actions.single.type, 'record');
    expect(actions.single.payload, <String, String>{'source': 'test'});
  });

  test('getActions ignores malformed native action maps', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
          if (methodCall.method != 'getActions') return null;
          return <Map<String, Object?>>[
            <String, Object?>{'title': 'Missing type'},
            <String, Object?>{'type': 'record', 'title': 'Record'},
          ];
        });

    final actions = await platform.getActions();

    expect(actions.single.type, 'record');
  });

  test('consumeLaunchAction parses and marks launch action', () async {
    final action = await platform.consumeLaunchAction();

    expect(action?.type, 'search');
    expect(action?.payload, <String, String>{'query': 'nostr'});
    expect(action?.isLaunchAction, isTrue);
  });

  test('native callbacks are emitted on the action stream', () async {
    final action = expectLater(
      platform.actionStream,
      emits(
        isA<DivineQuickActionEvent>()
            .having((event) => event.type, 'type', 'record')
            .having((event) => event.payload, 'payload', <String, String>{
              'source': 'callback',
            }),
      ),
    );

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('onQuickAction', <String, Object?>{
              'type': 'record',
              'payload': <String, String>{'source': 'callback'},
            }),
          ),
          (_) {},
        );

    await action;
  });

  test('malformed native callbacks are ignored', () async {
    final emitted = <DivineQuickActionEvent>[];
    final subscription = platform.actionStream.listen(emitted.add);

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('onQuickAction', <String, Object?>{
              'payload': <String, String>{},
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emitted, isEmpty);
    await subscription.cancel();
  });
}
