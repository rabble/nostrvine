import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);
typedef AndroidChooserLauncher = Future<void> Function(Uri uri, String title);
typedef ShareTextLauncher =
    Future<void> Function(String text, {String? subject});

String _buildFallbackShareText({
  required String toEmail,
  required String subject,
  required String body,
}) {
  return 'To: $toEmail\n'
      'Subject: $subject\n\n'
      '$body';
}

/// Launches a support email compose flow with platform-appropriate handoff.
///
/// On Android, this uses an explicit chooser around `ACTION_SENDTO` so the
/// user can pick an installed email app. On other platforms, it launches the
/// `mailto:` URI directly and falls back to the native share sheet if no mail
/// client is available.
class SupportEmailComposer {
  SupportEmailComposer({
    Future<bool> Function(Uri uri)? externalUriLauncher,
    Future<void> Function(Uri uri, String title)? androidChooserLauncher,
    Future<void> Function(String text, {String? subject})? shareTextLauncher,
  }) : _externalUriLauncher =
           externalUriLauncher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication)),
       _androidChooserLauncher =
           androidChooserLauncher ??
           ((uri, title) {
             final intent = AndroidIntent(
               action: 'android.intent.action.SENDTO',
               data: uri.toString(),
             );
             return intent.launchChooser(title);
           }),
       _shareTextLauncher =
           shareTextLauncher ??
           ((text, {subject}) async {
             await SharePlus.instance.share(
               ShareParams(text: text, subject: subject),
             );
           });

  final ExternalUriLauncher _externalUriLauncher;
  final AndroidChooserLauncher _androidChooserLauncher;
  final ShareTextLauncher _shareTextLauncher;

  Future<void> compose({
    required String toEmail,
    required String subject,
    required String body,
    String chooserTitle = 'Choose email app',
  }) async {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final mailtoUri = Uri.parse(
      'mailto:$toEmail?subject=$encodedSubject&body=$encodedBody',
    );

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _androidChooserLauncher(mailtoUri, chooserTitle);
        return;
      }

      final launched = await _externalUriLauncher(mailtoUri);
      if (launched) return;

      Log.warning(
        'Support email compose returned false, falling back to share sheet',
        name: 'SupportEmailComposer',
        category: LogCategory.ui,
      );
    } catch (error) {
      Log.warning(
        'Support email compose failed: $error. Falling back to share sheet',
        name: 'SupportEmailComposer',
        category: LogCategory.ui,
      );
    }

    await _shareTextLauncher(
      _buildFallbackShareText(toEmail: toEmail, subject: subject, body: body),
      subject: subject,
    );
  }
}
