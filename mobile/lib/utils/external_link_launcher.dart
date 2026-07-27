// ABOUTME: Shared launcher for outbound links with Divine route handling.
// ABOUTME: Centralizes external-link confirmation and trusted-domain policy.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/universal_link_resolver.dart';
import 'package:url_launcher/url_launcher.dart';

final _emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

const _trustedDomains = {
  'divine.video',
  'invite.divine.video',
  'login.divine.video',
  'media.divine.video',
  'relay.divine.video',
  'cdn.divine.video',
  'stream.divine.video',
};

bool isTrustedExternalLinkHost(String host) {
  final lower = host.toLowerCase();
  return _trustedDomains.any(
    (domain) => lower == domain || lower.endsWith('.$domain'),
  );
}

Future<void> openExternalLink(
  BuildContext context,
  String link, {
  bool requireConfirmationForUntrusted = true,
}) async {
  final uri = _uriFromLink(link);
  if (uri == null) return;

  final appRoute = divineUrlToPushRoute(uri);
  if (appRoute != null && context.mounted) {
    await context.push(appRoute);
    return;
  }

  if (requireConfirmationForUntrusted &&
      uri.scheme != 'mailto' &&
      !isTrustedExternalLinkHost(uri.host)) {
    if (!context.mounted) return;
    final confirmed = await _confirmExternalLink(context, uri);
    if (confirmed != true) return;
  }

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

Uri? _uriFromLink(String link) {
  final trimmed = link.trim();
  if (trimmed.isEmpty) return null;
  if (_emailRegex.hasMatch(trimmed)) {
    return Uri(scheme: 'mailto', path: trimmed);
  }
  final normalized =
      trimmed.startsWith(RegExp('https?://', caseSensitive: false))
      ? trimmed
      : 'https://$trimmed';
  return Uri.tryParse(normalized);
}

Future<bool?> _confirmExternalLink(BuildContext context, Uri uri) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        ctx.l10n.messageExternalLinkDialogTitle,
        style: VineTheme.titleMediumFont(),
      ),
      content: Text(
        ctx.l10n.messageExternalLinkDialogBody(uri.toString()),
        style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(
            ctx.l10n.commonCancel,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurface),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            ctx.l10n.messageExternalLinkDialogOpen,
            style: VineTheme.bodyMediumFont(color: VineTheme.primary),
          ),
        ),
      ],
    ),
  );
}
