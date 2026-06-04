// ABOUTME: Screen displayed when user's location is in a geo-blocked region
// ABOUTME: Shows information about regional restrictions and legal compliance

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/geo_blocking_service.dart';

class GeoBlockedScreen extends StatelessWidget {
  final GeoBlockResponse geoInfo;

  const GeoBlockedScreen({required this.geoInfo, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                const DivineIcon(
                  icon: DivineIconName.prohibit,
                  size: 80,
                  color: VineTheme.vineGreen,
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  context.l10n.geoBlockedTitle,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Region info
                Text(
                  geoInfo.region,
                  style: const TextStyle(
                    color: VineTheme.vineGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Explanation
                Text(
                  geoInfo.reason ?? context.l10n.geoBlockedDefaultReason,
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Additional info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: VineTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        context.l10n.geoBlockedCountryLabel,
                        geoInfo.country,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context.l10n.geoBlockedRegionLabel,
                        geoInfo.region,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        context.l10n.geoBlockedCityLabel,
                        geoInfo.city,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Legal notice
                Text(
                  context.l10n.geoBlockedLegalNotice,
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
