import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/profile_editor/profile_editor_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

class SaveButton extends StatelessWidget {
  const SaveButton({required this.canSave, required this.onSave, super.key});

  final bool canSave;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<ProfileEditorBloc, bool>(
      (bloc) => bloc.state.status == ProfileEditorStatus.loading,
    );

    return ElevatedButton(
      onPressed: (isLoading || !canSave) ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.onPrimary,
        disabledBackgroundColor: VineTheme.vineGreen.withValues(alpha: 0.4),
        disabledForegroundColor: VineTheme.onPrimary.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.profileSetupSavingButton,
                  style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
                ),
              ],
            )
          : Text(
              context.l10n.profileSetupSaveButton,
              style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}
