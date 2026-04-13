part of 'share_action_button.dart';

// ---------------------------------------------------------------------------
// "More actions" horizontal row
// ---------------------------------------------------------------------------

class _MoreActionsSection extends ConsumerWidget {
  const _MoreActionsSection({
    required this.video,
    required this.isOwnContent,
    required this.onSave,
    required this.onSaveWithWatermark,
    required this.onAddToList,
    required this.onCopyLink,
    required this.onShareVia,
    required this.onReport,
    required this.onCopyEventJson,
    required this.onCopyEventId,
    this.onSaveOriginal,
  });

  final VideoEvent video;
  final bool isOwnContent;
  final VoidCallback onSave;
  final Future<void> Function()? onSaveOriginal;
  final Future<void> Function() onSaveWithWatermark;
  final VoidCallback onAddToList;
  final VoidCallback onCopyLink;
  final VoidCallback onShareVia;
  final VoidCallback onReport;
  final VoidCallback onCopyEventJson;
  final VoidCallback onCopyEventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showCuratedLists = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    final showDebugTools = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.debugTools),
    );

    final actions = <_ActionData>[
      _ActionData(
        icon: DivineIconName.bookmarkSimple,
        label: context.l10n.shareSheetSave,
        onTap: onSave,
      ),
      if (onSaveOriginal != null)
        _ActionData(
          icon: DivineIconName.downloadSimple,
          label: context.l10n.shareSheetSaveToGallery,
          onTap: () => onSaveOriginal!.call(),
        ),
      _ActionData(
        icon: DivineIconName.downloadSimple,
        label: isOwnContent
            ? context.l10n.shareSheetSaveWithWatermark
            : context.l10n.shareSheetSaveVideo,
        onTap: onSaveWithWatermark,
      ),
      if (showCuratedLists)
        _ActionData(
          icon: DivineIconName.listPlus,
          label: context.l10n.shareSheetAddToList,
          onTap: onAddToList,
        ),
      _ActionData(
        icon: DivineIconName.linkSimple,
        label: context.l10n.shareSheetCopy,
        onTap: onCopyLink,
      ),
      _ActionData(
        icon: DivineIconName.shareFat,
        label: context.l10n.shareSheetShareVia,
        onTap: onShareVia,
      ),
      _ActionData(
        icon: DivineIconName.flag,
        label: context.l10n.shareSheetReport,
        onTap: onReport,
        isDestructive: true,
      ),
      if (showDebugTools) ...[
        _ActionData(
          icon: DivineIconName.bracketsAngle,
          label: context.l10n.shareSheetEventJson,
          onTap: onCopyEventJson,
        ),
        _ActionData(
          icon: DivineIconName.copySimple,
          label: context.l10n.shareSheetEventId,
          onTap: onCopyEventId,
        ),
      ],
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.shareSheetMoreActions,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final action = actions[index];
                return _ActionCircle(
                  icon: action.icon,
                  label: action.label,
                  isDestructive: action.isDestructive,
                  onTap: action.onTap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionData {
  const _ActionData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  static const double _circleSize = 48;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDestructive
        ? VineTheme.error.withValues(alpha: 0.15)
        : VineTheme.vineGreen.withValues(alpha: 0.15);
    final iconColor = isDestructive ? VineTheme.error : VineTheme.vineGreen;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Container(
                width: _circleSize,
                height: _circleSize,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: DivineIcon(icon: icon, size: 22, color: iconColor),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isDestructive
                      ? VineTheme.error
                      : VineTheme.secondaryText,
                  fontSize: 11,
                ),
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
