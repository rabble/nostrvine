import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/analytics_event_sink.dart';
import 'package:openvine/services/analytics_surface.dart';
import 'package:openvine/services/page_load_observer.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];
  final screenViews =
      <
        ({
          String screenName,
          String? screenClass,
          Map<String, Object>? parameters,
        })
      >[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    screenViews.add((
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    ));
  }
}

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
    late _RecordingAnalyticsEventSink sink;
    late PageLoadObserver observer;

    setUp(() {
      ScreenAnalyticsService.resetInstance();
      sink = _RecordingAnalyticsEventSink();
      observer = PageLoadObserver(
        analytics: ScreenAnalyticsService.testInstance(sink: sink),
      );
    });

    tearDown(ScreenAnalyticsService.resetInstance);

    test('creates an instance', () {
      expect(observer, isA<NavigatorObserver>());
    });

    testWidgets('tracks didPush for regular routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('logs semantic screen view for named routes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          navigatorObservers: [observer],
          home: const Scaffold(body: Text('Home')),
          onGenerateRoute: (settings) {
            if (settings.name == '/video/123') {
              return MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'video_detail'),
                builder: (_) => const Scaffold(body: Text('Video Detail')),
              );
            }
            return null;
          },
        ),
      );

      final context = tester.element(find.text('Home'));
      Navigator.of(context).pushNamed('/video/123');
      await tester.pumpAndSettle();

      expect(find.text('Video Detail'), findsOneWidget);
      expect(
        sink.screenViews.map((event) => event.screenName),
        contains('video_detail'),
      );
      expect(
        sink.screenViews.last.parameters,
        containsPair(AnalyticsParam.routeName, 'video_detail'),
      );
      expect(
        sink.screenViews.last.parameters,
        containsPair(AnalyticsParam.entryPoint, 'navigation'),
      );
    });
  });
}
