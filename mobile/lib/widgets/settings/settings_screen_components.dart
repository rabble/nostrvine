// ABOUTME: Figma-inspired visual primitives for the settings screen reskin
// ABOUTME: Provides text-first rows, section headings, and account summary UI

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class SettingsAccountSummaryBlock extends StatelessWidget {
  const SettingsAccountSummaryBlock({
    required this.title,
    required this.subtitle,
    this.bottomMargin = const EdgeInsets.only(bottom: 8),
    super.key,
  });

  final String title;
  final String subtitle;
  final EdgeInsets bottomMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: bottomMargin,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VineTheme.outlineDisabled),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: VineTheme.titleMediumFont(),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class SettingsSectionHeading extends StatelessWidget {
  const SettingsSectionHeading({
    required this.title,
    this.showTopDivider = true,
    super.key,
  });

  final String title;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
      decoration: BoxDecoration(
        border: showTopDivider
            ? const Border(
                top: BorderSide(color: VineTheme.outlineDisabled),
                bottom: BorderSide(color: VineTheme.outlineDisabled),
              )
            : const Border(
                bottom: BorderSide(color: VineTheme.outlineDisabled),
              ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: VineTheme.labelLargeFont(color: VineTheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class SettingsNavigationRow extends StatelessWidget {
  const SettingsNavigationRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.titleColor,
    this.showDivider = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? titleColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: VineTheme.outlineDisabled),
                  )
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: VineTheme.titleMediumFont(
                        color: titleColor ?? VineTheme.whiteText,
                        fontSize: 16,
                        height: 24 / 16,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 20),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: VineTheme.onSurfaceVariant,
                    size: 24,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.showDivider = true,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: VineTheme.outlineDisabled),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: VineTheme.titleMediumFont(
                    fontSize: 16,
                    height: 24 / 16,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 20),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: VineTheme.vineGreen,
            activeTrackColor: VineTheme.vineGreen.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class SettingsFooterRow extends StatelessWidget {
  const SettingsFooterRow({
    required this.label,
    required this.onTap,
    this.showDivider = true,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: VineTheme.outlineDisabled),
                  )
                : null,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: VineTheme.bodyMediumFont(
                color: VineTheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
