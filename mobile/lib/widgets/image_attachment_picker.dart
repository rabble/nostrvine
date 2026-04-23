import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/l10n/l10n.dart';

class ImageAttachmentPicker extends StatefulWidget {
  const ImageAttachmentPicker({
    required this.onChanged,
    super.key,
    this.maxImages = 3,
    this.enabled = true,
  });

  final int maxImages;
  final ValueChanged<List<XFile>> onChanged;
  final bool enabled;

  @override
  State<ImageAttachmentPicker> createState() => _ImageAttachmentPickerState();
}

class _ImageAttachmentPickerState extends State<ImageAttachmentPicker> {
  final List<XFile> _images = [];

  @visibleForTesting
  static ImagePicker imagePicker = ImagePicker();

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  Future<void> _pickImages() async {
    if (!widget.enabled) return;

    final remaining = widget.maxImages - _images.length;
    if (remaining <= 0) return;

    final picked = await imagePicker.pickMultiImage(
      maxWidth: 1920,
      imageQuality: 80,
    );

    if (picked.isEmpty) return;

    setState(() {
      final toAdd = picked.take(remaining).toList();
      _images.addAll(toAdd);
    });
    widget.onChanged(List.unmodifiable(_images));

    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.bugReportImagesCount(_images.length, widget.maxImages),
        TextDirection.ltr,
      );
    }
  }

  void _removeImage(int index) {
    if (!widget.enabled) return;

    setState(() {
      _images.removeAt(index);
    });
    widget.onChanged(List.unmodifiable(_images));

    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        context.l10n.bugReportImagesCount(_images.length, widget.maxImages),
        TextDirection.ltr,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobile) return const SizedBox.shrink();

    final l10n = context.l10n;
    final showAddButton = _images.length < widget.maxImages;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _images.length; i++)
          _Thumbnail(
            file: _images[i],
            enabled: widget.enabled,
            semanticsLabel: l10n.bugReportRemoveImage,
            onRemove: () => _removeImage(i),
          ),
        if (showAddButton)
          _AddButton(
            enabled: widget.enabled,
            semanticsLabel: l10n.bugReportAttachImages,
            onTap: _pickImages,
          ),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.file,
    required this.enabled,
    required this.semanticsLabel,
    required this.onRemove,
  });

  final XFile file;
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(file.path),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              semanticLabel: file.name,
              errorBuilder: (_, _, _) => Container(
                width: 64,
                height: 64,
                color: VineTheme.cardBackground,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: VineTheme.lightText,
                  size: 24,
                ),
              ),
            ),
          ),
          if (enabled)
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: semanticsLabel,
                child: GestureDetector(
                  onTap: onRemove,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: VineTheme.cardBackground,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: VineTheme.whiteText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    required this.enabled,
    required this.semanticsLabel,
    required this.onTap,
  });

  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: ExcludeSemantics(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: enabled ? VineTheme.vineGreen : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }
}
