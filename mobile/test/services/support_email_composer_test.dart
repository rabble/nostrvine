import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/support_email_composer.dart';

void main() {
  const toEmail = 'support@divine.video';
  const subject = 'Subject Line';
  const body = 'Body text here';

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('uses Android chooser on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    Uri? launchedUri;
    String? chooserTitle;
    var externalLaunchCalled = false;
    var shareCalled = false;

    final composer = SupportEmailComposer(
      androidChooserLauncher: (uri, title) async {
        launchedUri = uri;
        chooserTitle = title;
      },
      externalUriLauncher: (_) async {
        externalLaunchCalled = true;
        return true;
      },
      shareTextLauncher: (text, {subject}) async {
        shareCalled = true;
      },
    );

    await composer.compose(toEmail: toEmail, subject: subject, body: body);

    expect(launchedUri, isNotNull);
    expect(launchedUri!.scheme, 'mailto');
    expect(launchedUri!.path, toEmail);
    expect(launchedUri!.queryParameters['subject'], subject);
    expect(launchedUri!.queryParameters['body'], body);
    expect(launchedUri.toString(), isNot(contains('+')));
    expect(chooserTitle, 'Choose email app');
    expect(externalLaunchCalled, isFalse);
    expect(shareCalled, isFalse);
  });

  test('uses external mailto launcher on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    Uri? launchedUri;
    var shareCalled = false;

    final composer = SupportEmailComposer(
      externalUriLauncher: (uri) async {
        launchedUri = uri;
        return true;
      },
      shareTextLauncher: (text, {subject}) async {
        shareCalled = true;
      },
    );

    await composer.compose(toEmail: toEmail, subject: subject, body: body);

    expect(launchedUri, isNotNull);
    expect(launchedUri!.scheme, 'mailto');
    expect(launchedUri!.path, toEmail);
    expect(launchedUri!.queryParameters['subject'], subject);
    expect(launchedUri!.queryParameters['body'], body);
    expect(launchedUri.toString(), isNot(contains('+')));
    expect(shareCalled, isFalse);
  });

  test(
    'falls back to share sheet when external launch returns false',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      String? sharedText;
      String? sharedSubject;

      final composer = SupportEmailComposer(
        externalUriLauncher: (_) async => false,
        shareTextLauncher: (text, {subject}) async {
          sharedText = text;
          sharedSubject = subject;
        },
      );

      await composer.compose(toEmail: toEmail, subject: subject, body: body);

      expect(sharedText, contains(toEmail));
      expect(sharedText, contains(subject));
      expect(sharedText, contains(body));
      expect(sharedSubject, subject);
    },
  );

  test('falls back to share sheet when Android chooser throws', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    String? sharedText;

    final composer = SupportEmailComposer(
      androidChooserLauncher: (uri, title) {
        throw Exception('$title: $uri');
      },
      shareTextLauncher: (text, {subject}) async {
        sharedText = text;
      },
    );

    await composer.compose(toEmail: toEmail, subject: subject, body: body);

    expect(sharedText, contains(toEmail));
    expect(sharedText, contains(subject));
    expect(sharedText, contains(body));
  });
}
