// ABOUTME: Reusable settings tile for account-level content self-labels.
// ABOUTME: Used by Content & Safety and legacy content preferences routes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';

class AccountContentLabelsTile extends ConsumerStatefulWidget {
  const AccountContentLabelsTile({super.key});

  @override
  ConsumerState<AccountContentLabelsTile> createState() =>
      _AccountContentLabelsTileState();
}

class _AccountContentLabelsTileState
    extends ConsumerState<AccountContentLabelsTile> {
  Set<ContentLabel> _accountLabels = {};

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    final service = ref.read(accountLabelServiceProvider);
    if (mounted) {
      setState(() {
        _accountLabels = service.accountLabels;
      });
    }
  }

  Future<void> _selectLabels() async {
    final result = await showModalBottomSheet<Set<ContentLabel>>(
      context: context,
      backgroundColor: VineTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (_) => _AccountLabelMultiSelect(selected: _accountLabels),
    );

    if (result != null && mounted) {
      final service = ref.read(accountLabelServiceProvider);
      await service.setAccountLabels(result);
      setState(() {
        _accountLabels = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(
        Icons.warning_amber_rounded,
        color: VineTheme.vineGreen,
      ),
      title: Text(
        context.l10n.contentPreferencesAccountLabels,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        _accountLabels.isNotEmpty
            ? _accountLabels
                  .map(
                    (label) => localizedContentLabelName(context.l10n, label),
                  )
                  .join(', ')
            : context.l10n.contentPreferencesAccountLabelsEmpty,
        style: const TextStyle(color: VineTheme.lightText, fontSize: 14),
      ),
      trailing: const Icon(Icons.chevron_right, color: VineTheme.lightText),
      onTap: _selectLabels,
    );
  }
}

class _AccountLabelMultiSelect extends StatefulWidget {
  const _AccountLabelMultiSelect({required this.selected});

  final Set<ContentLabel> selected;

  @override
  State<_AccountLabelMultiSelect> createState() =>
      _AccountLabelMultiSelectState();
}

class _AccountLabelMultiSelectState extends State<_AccountLabelMultiSelect> {
  late Set<ContentLabel> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.selected);
  }

  void _toggle(ContentLabel label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selected.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VineTheme.onSurfaceMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.contentPreferencesAccountContentLabels,
                    style: VineTheme.titleLargeFont(),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      child: Text(
                        context.l10n.contentPreferencesClearAll,
                        style: const TextStyle(color: VineTheme.vineGreen),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.l10n.contentPreferencesSelectAllThatApply,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: ContentLabel.values.length,
                itemBuilder: (context, index) {
                  final label = ContentLabel.values[index];
                  final isChecked = _selected.contains(label);
                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (_) => _toggle(label),
                    title: Text(
                      localizedContentLabelName(context.l10n, label),
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 15,
                      ),
                    ),
                    activeColor: VineTheme.vineGreen,
                    checkColor: VineTheme.whiteText,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: VineTheme.whiteText,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _selected.isEmpty
                          ? context.l10n.contentPreferencesDoneNoLabels
                          : context.l10n.contentPreferencesDoneCount(
                              _selected.length,
                            ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
