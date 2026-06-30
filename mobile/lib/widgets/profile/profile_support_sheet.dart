// ABOUTME: Profile support affordance sheet for outbound monetization links.
// ABOUTME: Groups one-time tips separately from subscription/support links.

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_analytics.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/external_link_launcher.dart';

Future<void> showProfileSupportSheet({
  required BuildContext context,
  required List<MonetizationLink> links,
  required AnalyticsEventSink analytics,
}) {
  final appStoreTipPolicy = usesAppleAppStoreTipPolicy;
  final visibleLinks = monetizationLinksForCurrentStorefront(links);
  final tipLinks = visibleLinks
      .where((link) => link.category == MonetizationLinkCategory.tip)
      .toList(growable: false);
  final subscriptionLinks = visibleLinks
      .where((link) => link.category == MonetizationLinkCategory.subscription)
      .toList(growable: false);

  return VineBottomSheet.show<void>(
    context: context,
    scrollable: false,
    expanded: false,
    contentTitle: appStoreTipPolicy
        ? context.l10n.profileTipSheetTitle
        : context.l10n.profileSupportSheetTitle,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          appStoreTipPolicy
              ? context.l10n.profileTipSheetBody
              : context.l10n.profileSupportSheetBody,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
        ),
      ),
      if (tipLinks.isNotEmpty)
        _SupportLinkGroup(
          title: context.l10n.profileSupportTipSection,
          links: tipLinks,
          analytics: analytics,
        ),
      if (subscriptionLinks.isNotEmpty)
        _SupportLinkGroup(
          title: context.l10n.profileSupportSubscriptionSection,
          links: subscriptionLinks,
          analytics: analytics,
        ),
      const SizedBox(height: 8),
    ],
  );
}

class _SupportLinkGroup extends StatelessWidget {
  const _SupportLinkGroup({
    required this.title,
    required this.links,
    required this.analytics,
  });

  final String title;
  final List<MonetizationLink> links;
  final AnalyticsEventSink analytics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            title.toUpperCase(),
            style: VineTheme.labelSmallFont(color: VineTheme.onSurfaceVariant),
          ),
          for (final link in links)
            _SupportLinkTile(link: link, analytics: analytics),
        ],
      ),
    );
  }
}

class _SupportLinkTile extends StatelessWidget {
  const _SupportLinkTile({required this.link, required this.analytics});

  final MonetizationLink link;
  final AnalyticsEventSink analytics;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        trackMonetizationOutboundClicked(analytics: analytics, link: link);
        await openExternalLink(context, link.url);
        if (context.mounted) Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VineTheme.outlineMuted),
        ),
        child: Row(
          children: [
            const DivineIcon(
              icon: DivineIconName.linkSimple,
              color: VineTheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                link.provider.displayName,
                style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              ),
            ),
            const DivineIcon(
              icon: DivineIconName.arrowUpRight,
              color: VineTheme.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
