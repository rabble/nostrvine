import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/page_load_observer.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakeFirebaseCore extends Fake
    with MockPlatformInterfaceMixin
    implements FirebasePlatform {
  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return _FakeFirebaseApp();
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return _FakeFirebaseApp();
  }

  @override
  List<FirebaseAppPlatform> get apps => [_FakeFirebaseApp()];
}

class _FakeFirebaseApp extends Fake
    with MockPlatformInterfaceMixin
    implements FirebaseAppPlatform {
  @override
  String get name => defaultFirebaseAppName;

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'test-api-key',
    appId: 'test-app-id',
    messagingSenderId: 'test-sender-id',
    projectId: 'test-project-id',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FirebasePlatform.instance = _FakeFirebaseCore();

  group(PageLoadObserver, () {
    late PageLoadObserver observer;

    setUp(() {
      observer = PageLoadObserver();
    });

    test('creates an instance', () {
      expect(observer, isA<NavigatorObserver>());
    });

    testWidgets('tracks didPush for regular routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          routes: {'/test': (_) => const Scaffold(body: Text('Test'))},
        ),
      );

      final context = tester.element(find.text('Home'));
      Navigator.of(context).pushNamed('/test');
      await tester.pumpAndSettle();

      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('skips popup routes without crashing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const AlertDialog(content: Text('Dialog')),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog'), findsOneWidget);
    });

    testWidgets('tracks didPop for regular routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          routes: {
            '/test': (_) => Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ),
            ),
          },
        ),
      );

      final context = tester.element(find.text('Home'));
      Navigator.of(context).pushNamed('/test');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go Back'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
    });
  });
}
