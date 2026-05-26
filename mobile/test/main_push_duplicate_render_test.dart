// ABOUTME: Tests the background push de-duplication guard — the app must not
// ABOUTME: render a local notification when the OS already presents one (#4731).

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;

void main() {
  group('shouldRenderLocalPushNotification', () {
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
  });
}
