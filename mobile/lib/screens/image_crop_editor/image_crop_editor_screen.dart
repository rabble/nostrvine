import 'dart:io';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/image_crop_editor/widgets/image_crop_editor_bottom_bar.dart';
import 'package:openvine/screens/image_crop_editor/widgets/image_crop_editor_toolbar.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// What is being cropped. Determines the locked aspect ratio, the bounded
/// output size of the re-encoded result, and the filename handed to the
/// upload service.
enum ImageCropKind {
  /// Square 1:1 avatar, output capped at 1024x1024.
  avatar(
    aspectRatio: 1,
    maxOutputSize: Size(1024, 1024),
    filename: 'avatar.jpg',
    mimeType: 'image/jpeg',
  ),

  /// 3:1 banner, output capped at 1500x500.
  banner(
    aspectRatio: 3,
    maxOutputSize: Size(1500, 500),
    filename: 'banner.jpg',
    mimeType: 'image/jpeg',
  );

  const ImageCropKind({
    required this.aspectRatio,
    required this.maxOutputSize,
    required this.filename,
    required this.mimeType,
  });

  /// Locked width-to-height ratio of the crop frame.
  final double aspectRatio;

  /// Bounding box the re-encoded image is scaled to fit within.
  final Size maxOutputSize;

  /// Filename passed alongside the cropped bytes to the upload service. The
  /// extension matches the editor's JPEG output format.
  final String filename;

  /// MIME type of the cropped bytes, matching the editor's output format.
  final String mimeType;
}

/// Pushes the Vine-styled crop editor and resolves to the cropped JPEG bytes,
/// or `null` if the user cancelled.
///
/// Exactly one of [file] / [bytes] must be supplied — [file] for native picks
/// (real filesystem path), [bytes] for web picks (blob already read into
/// memory).
Future<Uint8List?> showImageCropEditor(
  BuildContext context, {
  required ImageCropKind kind,
  File? file,
  Uint8List? bytes,
}) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute<Uint8List>(
      fullscreenDialog: true,
      builder: (_) => ImageCropEditorScreen(
        kind: kind,
        file: file,
        bytes: bytes,
      ),
    ),
  );
}

/// Full-screen crop / rotate / flip editor wrapping `pro_image_editor`'s
/// standalone [CropRotateEditor] with Vine chrome.
///
/// The editor re-encodes the result to [ImageCropKind.maxOutputSize] as a
/// fresh JPEG (`enableUseOriginalBytes: false`), which bounds the upload
/// dimensions and drops the original EXIF as a side effect. Returns the bytes
/// via `Navigator.pop`.
class ImageCropEditorScreen extends StatefulWidget {
  const ImageCropEditorScreen({
    required this.kind,
    this.file,
    this.bytes,
    super.key,
  }) : assert(
         (file == null) != (bytes == null),
         'Exactly one of file or bytes must be supplied',
       );

  final ImageCropKind kind;
  final File? file;
  final Uint8List? bytes;

  @override
  State<ImageCropEditorScreen> createState() => _ImageCropEditorScreenState();
}

class _ImageCropEditorScreenState extends State<ImageCropEditorScreen> {
  /// Captured cropped bytes. `done()` fills this via [onImageEditingComplete]
  /// before [onCloseEditor] pops; the close button pops with it still null.
  Uint8List? _result;

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    return CropRotateEditor.autoSource(
      file: widget.file,
      byteArray: widget.bytes,
      initConfigs: CropRotateEditorInitConfigs(
        theme: Theme.of(context),
        convertToUint8List: true,
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (bytes) async {
            _result = bytes;
            Log.info(
              'Cropped ${kind.name}: ${bytes.lengthInBytes} bytes '
              '(${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
              name: 'ImageCropEditor',
              category: LogCategory.ui,
            );
          },
          onCloseEditor: (_) {
            if (mounted) Navigator.of(context).pop(_result);
          },
        ),
        configs: ProImageEditorConfigs(
          i18n: I18n(
            doneLoadingMsg: context.l10n.imageCropEditorProcessing,
          ),
          progressIndicatorConfigs: const ProgressIndicatorConfigs(
            widgets: ProgressIndicatorWidgets(
              circularProgressIndicator: BrandedLoadingIndicator(size: 64),
            ),
          ),
          imageGeneration: ImageGenerationConfigs(
            maxOutputSize: kind.maxOutputSize,
            enableUseOriginalBytes: false,
          ),
          cropRotateEditor: CropRotateEditorConfigs(
            initAspectRatio: kind.aspectRatio,
            exportOvalMask: false,
            enableFlipAnimation: false,
            enableKeepAspectRatioOnRotate: kind == .banner,
            rotateDirection: .right,
            style: const CropRotateEditorStyle(
              background: VineTheme.surfaceBackground,
              cropCornerColor: VineTheme.primary,
            ),
            widgets: CropRotateEditorWidgets(
              appBar: (editorState, rebuildStream) => ReactiveAppbar(
                stream: rebuildStream,
                builder: (_) => ImageCropEditorToolbar(
                  onClose: editorState.close,
                  onDone: editorState.done,
                ),
              ),
              bottomBar: (editorState, rebuildStream) => ReactiveWidget(
                stream: rebuildStream,
                builder: (_) => ImageCropEditorBottomBar(
                  onRotate: editorState.rotate,
                  onFlip: editorState.flip,
                  onReset: editorState.reset,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
