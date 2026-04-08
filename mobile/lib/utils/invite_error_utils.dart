// ABOUTME: Shared invite activation error mapping for auth and onboarding flows

import 'package:invite_api_client/invite_api_client.dart';

class InviteErrorUtils {
  static String activationFailureMessage(InviteApiException error) {
    final statusCode = error.statusCode;
    final normalizedMessage = error.message.toLowerCase();

    final isUsedError =
        statusCode == 409 ||
        normalizedMessage.contains('already used') ||
        normalizedMessage.contains('already claimed') ||
        normalizedMessage.contains('already been used') ||
        normalizedMessage.contains('already joined');

    if (isUsedError) {
      return 'That invite code is no longer available. '
          'Go back to your invite code, join the waitlist, or contact support.';
    }

    final isInvalidError =
        statusCode == 403 ||
        statusCode == 404 ||
        normalizedMessage.contains('invalid') ||
        normalizedMessage.contains('revoked') ||
        normalizedMessage.contains('expired') ||
        normalizedMessage.contains('not eligible');

    if (isInvalidError) {
      return 'That invite code cannot be used right now. '
          'Go back to your invite code, join the waitlist, or contact support.';
    }

    final isTemporaryError =
        statusCode == 429 ||
        (statusCode != null && statusCode >= 500) ||
        normalizedMessage.contains('timed out') ||
        normalizedMessage.contains('timeout') ||
        normalizedMessage.contains('network') ||
        normalizedMessage.contains('socket') ||
        normalizedMessage.contains('connection');

    if (isTemporaryError) {
      return "We couldn't confirm your invite right now. "
          'Go back to your invite code and try again, or contact support.';
    }

    return "We couldn't activate your invite. "
        'Go back to your invite code, join the waitlist, or contact support.';
  }
}
