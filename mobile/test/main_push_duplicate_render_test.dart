// ABOUTME: Tests the background push de-duplication guard — the app must not
// ABOUTME: render a local notification when the OS already presents one (#4731).

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  group('shouldRenderLocalPushNotification', () {
    // Unit-tests the pure decision predicate only. The background handler that
    // consumes it (_firebaseMessagingBackgroundHandler) calls
    // Firebase.initializeApp() and the local-notifications plugin, so its
    // early-return is verified on-device, not here (#4731).
    test('does not render when the OS already presents the notification — an '
        'iOS alert push surfaces RemoteMessage.notification', () {
      const message = RemoteMessage(
        notification: RemoteNotification(
          title: 'New like',
          body: 'alice liked your video',
        ),
        data: {'body': 'alice liked your video', 'type': 'like'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test('renders for a data-only message that carries a body '
        '(Android / iOS data push)', () {
      const message = RemoteMessage(
        data: {'title': 'New like', 'body': 'alice liked your video'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isTrue);
    });

    test('does not render a data-only message with no body', () {
      const message = RemoteMessage(data: {'type': 'like'});

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test('OS presentation wins even when the data payload also carries a '
        'body', () {
      const message = RemoteMessage(
        notification: RemoteNotification(title: 't', body: 'b'),
        data: {'body': 'b'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test(
      'does not render a data-only message whose body is an empty string',
      () {
        const message = RemoteMessage(data: {'body': '', 'type': 'like'});

        expect(app.shouldRenderLocalPushNotification(message), isFalse);
      },
    );

    test('does not render when the data body is not a string', () {
      const message = RemoteMessage(data: <String, dynamic>{'body': 1});

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });

    test('does not render when the OS presents the alert and the data '
        'carries no body', () {
      const message = RemoteMessage(
        notification: RemoteNotification(title: 'New follower', body: 'bob'),
        data: {'type': 'follow'},
      );

      expect(app.shouldRenderLocalPushNotification(message), isFalse);
    });
  });
}
