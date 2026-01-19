// ABOUTME: Options modal for comment actions (e.g., delete)
// ABOUTME: Shows as bottom sheet with action options

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet.dart';

/// Modal bottom sheet displaying options for a comment.
///
/// Currently supports:
/// - Delete comment
///
/// Returns `true` if delete was selected, `null` if cancelled.
class CommentOptionsModal {
  /// Shows the options modal and returns the result.
  ///
  /// Returns `true` if delete was selected, `null` if cancelled.
  static Future<bool?> show(BuildContext modalContext) {
    return VineBottomSheet.show<bool>(
      context: modalContext,
      initialChildSize: 0.2,
      minChildSize: 0.2,
      title: Text(
        'Options',
        style: VineTheme.titleFont(fontSize: 16, color: VineTheme.onSurface),
      ),
      children: [
        Semantics(
          identifier: 'delete_comment_option',
          button: true,
          label: 'Delete comment',
          child: GestureDetector(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icon/delete.svg',
                    height: 18,
                    colorFilter: const ColorFilter.mode(
                      Colors.red,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Delete ',
                    style: VineTheme.bodyFont(
                      color: Colors.red,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => modalContext.pop(true),
          ),
        ),
      ],
    );
  }
}
