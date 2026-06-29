import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:unified_logger/unified_logger.dart';

/// Whether the host is a desktop OS for image-picker routing.
///
/// Always returns false on web — `defaultTargetPlatform` reports the host OS
/// in a desktop browser, but a browser is not desktop for picker-routing
/// purposes (no real filesystem access).
bool isDesktopImagePickerPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Picks a single image, returning the picker's [XFile] without resolving it
/// to a `dart:io File`.
///
/// The returned XFile may have a blob-URL `path` on web; callers must use
/// [XFile.readAsBytes] there rather than constructing a `File`. On native
/// desktop gallery picks, `file_selector` is used for a richer file-type
/// filter UX; everything else goes through `image_picker`.
Future<XFile?> pickProfileXFile(
  ImageSource source,
  ImagePicker picker,
  BuildContext context,
) async {
  if (!kIsWeb &&
      source == ImageSource.gallery &&
      isDesktopImagePickerPlatform()) {
    return _pickXFileFromDesktop(context);
  }

  try {
    return await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  } catch (e) {
    Log.error(
      'image_picker error: $e',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );
    rethrow;
  }
}

Future<XFile?> _pickXFileFromDesktop(BuildContext context) async {
  try {
    Log.info(
      '🖥️ Starting desktop file picker...',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );

    final typeGroup = XTypeGroup(
      label: context.l10n.profileSetupImagesTypeGroup,
      extensions: const <String>['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

    if (file == null) {
      Log.info(
        '❌ Desktop file picker: User cancelled or no file selected',
        name: 'ProfileSetupScreen',
        category: LogCategory.ui,
      );
      return null;
    }

    Log.info(
      '✅ Desktop file selected: ${file.name}',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );
    return file;
  } catch (e) {
    Log.error(
      'Desktop file picker error: $e',
      name: 'ProfileSetupScreen',
      category: LogCategory.ui,
    );
    rethrow;
  }
}
