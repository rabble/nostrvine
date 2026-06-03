import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays username availability status (checking, available, taken, reserved, error)
class UsernameStatusIndicator extends StatelessWidget {
  const UsernameStatusIndicator({
    required this.status,
    this.error,
    this.formatMessage,
    super.key,
  });

  final UsernameStatus status;
  final UsernameValidationError? error;

  /// Custom message from the server for format validation errors.
  final String? formatMessage;

  @override
  Widget build(BuildContext context) {
    String? errorText;
    if (error != null) {
      errorText = switch (error) {
        UsernameValidationError.invalidFormat =>
          formatMessage ?? context.l10n.profileSetupUsernameInvalidFormat,
        UsernameValidationError.invalidLength =>
          context.l10n.profileSetupUsernameInvalidLength,
        UsernameValidationError.networkError =>
          context.l10n.profileSetupUsernameNetworkError,
        null => null,
      };
    }
    return switch (status) {
      UsernameStatus.idle => const SizedBox.shrink(),
      UsernameStatus.checking => const _UsernameCheckingIndicator(),
      UsernameStatus.available => const _UsernameAvailableIndicator(),
      UsernameStatus.taken => const _UsernameTakenIndicator(),
      UsernameStatus.reserved => const _UsernameReservedIndicator(),
      UsernameStatus.burned => const _UsernameBurnedIndicator(),
      UsernameStatus.invalidFormat => _UsernameErrorIndicator(
        message:
            errorText ?? context.l10n.profileSetupUsernameInvalidFormatGeneric,
      ),
      UsernameStatus.error => _UsernameErrorIndicator(
        message: errorText ?? context.l10n.profileSetupUsernameCheckFailed,
      ),
    };
  }
}

/// Lowercases input text on every edit.
///
/// Composes with `FilteringTextInputFormatter` on the username field so that
/// typed capital letters are normalized in place rather than triggering the
/// lowercase-only validator. Lowercasing ASCII is a 1:1 character mapping so
/// the existing selection offsets remain valid.
class LowercaseTextInputFormatter extends TextInputFormatter {
  const LowercaseTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lowered = newValue.text.toLowerCase();
    if (lowered == newValue.text) return newValue;
    return newValue.copyWith(text: lowered);
  }
}

class _UsernameCheckingIndicator extends StatelessWidget {
  const _UsernameCheckingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.profileSetupUsernameChecking,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsernameAvailableIndicator extends StatelessWidget {
  const _UsernameAvailableIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const DivineIcon(
            icon: DivineIconName.checkCircle,
            color: VineTheme.vineGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.profileSetupUsernameAvailable,
            style: const TextStyle(color: VineTheme.vineGreen, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UsernameTakenIndicator extends StatelessWidget {
  const _UsernameTakenIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.cancel, color: VineTheme.error, size: 16),
          const SizedBox(width: 8),
          Text(
            context.l10n.profileSetupUsernameTakenIndicator,
            style: const TextStyle(color: VineTheme.error, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UsernameReservedIndicator extends StatelessWidget {
  const _UsernameReservedIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.lockSimple,
                color: VineTheme.warning,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.profileSetupUsernameReserved,
                style: const TextStyle(
                  color: VineTheme.warning,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final username = context
                      .read<ProfileEditorBloc>()
                      .state
                      .username;
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) => BlocProvider.value(
                      value: context.read<ProfileEditorBloc>(),
                      child: UsernameReservedDialog(username),
                    ),
                  );
                },
                child: Text(
                  context.l10n.profileSetupContactSupport,
                  style: const TextStyle(
                    color: VineTheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.read<ProfileEditorBloc>().add(
                  const UsernameRechecked(),
                ),
                child: Text(
                  context.l10n.profileSetupCheckAgain,
                  style: const TextStyle(
                    color: VineTheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UsernameBurnedIndicator extends StatelessWidget {
  const _UsernameBurnedIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.cancel, color: VineTheme.error, size: 16),
          const SizedBox(width: 8),
          Text(
            context.l10n.profileSetupUsernameBurned,
            style: const TextStyle(color: VineTheme.error, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _UsernameErrorIndicator extends StatelessWidget {
  const _UsernameErrorIndicator({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            color: VineTheme.error,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: VineTheme.error, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

@visibleForTesting
class UsernameReservedDialog extends StatefulWidget {
  const UsernameReservedDialog(this.username, {super.key});

  final String username;

  @override
  State<UsernameReservedDialog> createState() => _UsernameReservedDialogState();
}

class _UsernameReservedDialogState extends State<UsernameReservedDialog> {
  final _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _contactSupport() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) return;

    setState(() => _submitting = true);

    final npub = ZendeskSupportService.userNpub;
    final created = await ZendeskSupportService.createTicketViaApi(
      subject: 'Reserved username request: ${widget.username}',
      description:
          'Username requested: ${widget.username}\n'
          '${npub != null ? 'Nostr npub: $npub\n' : ''}\n'
          'Why this name should be mine:\n$reason',
      requesterName: ZendeskSupportService.userName,
      requesterEmail: ZendeskSupportService.userEmail,
      tags: ['reserved_username', 'name_request'],
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (created) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileSetupSupportRequestSent),
          backgroundColor: VineTheme.vineGreen,
        ),
      );
    } else {
      final encodedReason = Uri.encodeComponent(reason);
      final launched = await launchUrl(
        Uri.parse(
          'mailto:names@divine.video?subject=Reserved username request: '
          '${widget.username}&body=Username requested: ${widget.username}'
          '%0A%0AWhy this name should be mine:%0A$encodedReason',
        ),
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.profileSetupCouldntOpenEmail),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        context.l10n.profileSetupUsernameReservedTitle,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.profileSetupUsernameReservedBody(widget.username),
            style: const TextStyle(color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 14),
            decoration: InputDecoration(
              hintText: context.l10n.profileSetupUsernameReservedHint,
              hintStyle: const TextStyle(color: VineTheme.onSurfaceMuted),
              border: const OutlineInputBorder(),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.surfaceContainer),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: VineTheme.vineGreen),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.profileSetupUsernameReservedCheckHint,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.l10n.commonClose,
            style: const TextStyle(color: VineTheme.lightText),
          ),
        ),
        TextButton(
          onPressed: () {
            context.read<ProfileEditorBloc>().add(const UsernameRechecked());
            Navigator.of(context).pop();
          },
          child: Text(
            context.l10n.profileSetupCheckAgain,
            style: const TextStyle(color: VineTheme.vineGreen),
          ),
        ),
        FilledButton(
          onPressed: _submitting ? null : _contactSupport,
          style: FilledButton.styleFrom(backgroundColor: VineTheme.vineGreen),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.whiteText,
                  ),
                )
              : Text(context.l10n.profileSetupSendRequest),
        ),
      ],
    );
  }
}
