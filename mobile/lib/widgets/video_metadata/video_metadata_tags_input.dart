import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Input widget for adding and managing hashtags for video metadata.
///
/// Supports up to 10 tags, allows adding multiple tags by pasting,
/// and displays tags as removable chips in a custom flow layout.
class VideoMetadataTagsInput extends ConsumerStatefulWidget {
  /// Creates a video metadata tags input widget.
  const VideoMetadataTagsInput({super.key});

  @override
  ConsumerState<VideoMetadataTagsInput> createState() =>
      _VideoMetadataTagsInputState();
}

class _VideoMetadataTagsInputState
    extends ConsumerState<VideoMetadataTagsInput> {
  final _controller = TextEditingController();
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        // Handle backspace on empty text field to restore last tag
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controller.text.isEmpty) {
          _handleBackspace();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );

    // Rebuild when focus changes to update label color
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Handles backspace key press when text field is empty.
  /// Removes the last tag and puts it back in the text field for editing.
  void _handleBackspace() {
    if (_controller.text.isNotEmpty) return;

    final tags = ref.read(videoEditorProvider).tags;
    if (tags.isEmpty) return;

    // Get the last tag
    final lastTag = tags.last;
    Log.debug(
      '#️⃣ Tag removed via backspace: $lastTag',
      name: 'VideoMetadataTagsInput',
      category: LogCategory.video,
    );

    // Remove it from tags
    final newTags = tags.toSet()..remove(lastTag);
    ref.read(videoEditorProvider.notifier).updateMetadata(tags: newTags);

    // Put it back in the text field for editing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.text = lastTag;
    });
  }

  /// Processes input value and extracts valid tags.
  ///
  /// Handles multiple tags separated by whitespace (e.g., pasted text).
  /// Filters out invalid characters and empty strings.
  void _handleTagChanges(String value, {bool isSubmitted = false}) {
    // Only process if value contains whitespace
    if ((isSubmitted && value.trim().isEmpty) ||
        (!isSubmitted && !value.contains(RegExp(r'\s')))) {
      return;
    }

    // Extract and sanitize multiple tags (supports copy/paste)
    // For the case the user copy/paste multiple tags, we need to extract
    // them separate.
    final newTags = value
        .split(RegExp(r'\s+'))
        .map((tag) => tag.replaceAll(RegExp('[^a-zA-Z0-9]'), ''))
        .where((tag) => tag.isNotEmpty)
        .toSet();

    // Merge with existing tags
    final oldTags = ref.read(videoEditorProvider).tags;
    final updatedTags = {...oldTags, ...newTags};
    final addedTags = newTags.difference(oldTags);
    if (addedTags.isNotEmpty) {
      Log.debug(
        '#️⃣ Tags added: ${addedTags.join(', ')} (total: ${updatedTags.length})',
        name: 'VideoMetadataTagsInput',
        category: LogCategory.video,
      );
    }
    ref.read(videoEditorProvider.notifier).updateMetadata(tags: updatedTags);
    _controller.clear();
    // Keep focus to prevent keyboard from closing (after rebuild).
    //
    // We request focus twice: once immediately and once in a post-frame
    // callback to prevent an issue where focus could be lost during the widget
    // rebuild triggered by the state update.
    if (updatedTags.length < VideoEditorConstants.tagLimit) {
      _focusNode.requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic label color based on focus state
    final labelStyle = VineTheme.bodyFont(
      color: _focusNode.hasFocus
          ? const Color(0xFF27C58B)
          : const Color(0xB6FFFFFF),
      fontSize: 11,
      fontWeight: .w600,
      height: 1.45,
      letterSpacing: 0.5,
    );

    final tags = ref.watch(videoEditorProvider.select((s) => s.tags));

    return GestureDetector(
      onTap: _focusNode.requestFocus,
      behavior: .opaque,
      child: Padding(
        padding: const .all(16),
        child: Column(
          crossAxisAlignment: .start,
          spacing: 12,
          children: [
            // Show count when tags exist
            if (tags.isNotEmpty)
              Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  Flexible(child: Text('Tags', style: labelStyle)),
                  if (VideoEditorConstants.enableTagLimit)
                    Text(
                      '${tags.length}/${VideoEditorConstants.tagLimit}',
                      style: labelStyle.copyWith(
                        color: const Color(0x80FFFFFF),
                      ),
                    ),
                ],
              ),
            // Custom flow layout for tags and input field
            _TagInputLayout(
              spacing: 8,
              runSpacing: 8,
              minTextFieldWidth: 100,
              tagCount: tags.length,
              children: [
                // Render all existing tags as chips
                ...tags.map((tag) => _TagChip(tag: tag)),
                // Show input field if under limit
                if (tags.length < VideoEditorConstants.tagLimit)
                  DivineTextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    label: tags.isEmpty ? 'Tags' : null,
                    contentPadding: .zero,
                    textInputAction: .done,
                    maxLines: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9\s]'),
                      ),
                    ],
                    onChanged: _handleTagChanges,
                    onSubmitted: (value) =>
                        _handleTagChanges(value, isSubmitted: true),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip widget displaying a hashtag with a delete button.
class _TagChip extends ConsumerWidget {
  /// Creates a tag chip.
  const _TagChip({required this.tag});

  /// The tag text without the '#' prefix.
  final String tag;

  void _removeTag(WidgetRef ref) {
    final tags = ref.read(videoEditorProvider).tags;

    final resultTags = {...tags};
    resultTags.removeWhere((el) => el == tag);
    Log.debug(
      '#️⃣ Tag removed: $tag (remaining: ${resultTags.length})',
      name: 'VideoMetadataTagsInput',
      category: LogCategory.video,
    );

    ref.read(videoEditorProvider.notifier).updateMetadata(tags: resultTags);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const .symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: .circular(16),
        color: const Color(0xFF032017),
      ),
      child: Row(
        mainAxisSize: .min,
        children: [
          // Hashtag symbol
          Text(
            '#',
            style: VineTheme.bodyFont(
              color: const Color(0xFF27C58B),
              height: 1.50,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(width: 4),
          // Tag text
          Flexible(
            child: Text(
              tag,
              overflow: .ellipsis,
              style: GoogleFonts.bricolageGrotesque(
                color: VineTheme.onSurface,
                fontSize: 14,
                fontWeight: .w800,
                height: 1.43,
                letterSpacing: 0.10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            // TODO(l10n): Replace with context.l10n when localization is added.
            label: 'Delete',
            hint: 'Delete Tag $tag',
            button: true,
            child: GestureDetector(
              onTap: () => _removeTag(ref),
              child: const DivineIcon(
                icon: .x,
                size: 16,
                color: VineTheme.onSurfaceMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom layout widget that wraps children like Wrap but gives the last
/// child (the text field) the remaining width in the current row.
///
/// This creates a flow layout where tag chips wrap naturally, and the input
/// field fills the remaining space or moves to a new line if space is
/// insufficient.
class _TagInputLayout extends MultiChildRenderObjectWidget {
  /// Creates a tag input layout.
  const _TagInputLayout({
    required this.spacing,
    required this.runSpacing,
    required this.tagCount,
    required this.minTextFieldWidth,
    required super.children,
  });

  /// Horizontal spacing between children.
  final double spacing;

  /// Vertical spacing between rows.
  final double runSpacing;

  /// Number of tag chips (used to identify the text field).
  final int tagCount;

  /// Minimum width for the text field.
  final double minTextFieldWidth;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderTagInputLayout(
      spacing: spacing,
      runSpacing: runSpacing,
      tagCount: tagCount,
      minTextFieldWidth: minTextFieldWidth,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTagInputLayout renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..tagCount = tagCount
      ..minTextFieldWidth = minTextFieldWidth;
  }
}

/// Parent data for children in [_TagInputLayout].
class _TagInputLayoutParentData extends ContainerBoxParentData<RenderBox> {}

/// Render object that implements the custom tag input layout algorithm.
///
/// Lays out tag chips in a flow layout and gives the text field
/// the remaining width in the current row, or moves it to a new row.
class _RenderTagInputLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TagInputLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _TagInputLayoutParentData> {
  _RenderTagInputLayout({
    required double spacing,
    required double runSpacing,
    required int tagCount,
    required double minTextFieldWidth,
  }) : _spacing = spacing,
       _runSpacing = runSpacing,
       _tagCount = tagCount,
       _minTextFieldWidth = minTextFieldWidth;

  double _spacing;
  double _runSpacing;
  int _tagCount;
  double _minTextFieldWidth;

  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing != value) {
      _spacing = value;
      markNeedsLayout();
    }
  }

  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing != value) {
      _runSpacing = value;
      markNeedsLayout();
    }
  }

  int get tagCount => _tagCount;
  set tagCount(int value) {
    if (_tagCount != value) {
      _tagCount = value;
      markNeedsLayout();
    }
  }

  double get minTextFieldWidth => _minTextFieldWidth;
  set minTextFieldWidth(double value) {
    if (_minTextFieldWidth != value) {
      _minTextFieldWidth = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _TagInputLayoutParentData) {
      child.parentData = _TagInputLayoutParentData();
    }
  }

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth;
    double x = 0;
    double y = 0;
    double maxHeightInRow = 0;

    // Track children in current row for vertical centering
    final currentRowChildren = <RenderBox>[];

    // Layout all tag chips in flow layout
    var child = firstChild;
    var index = 0;
    RenderBox? textFieldChild;

    while (child != null) {
      final parentData = child.parentData! as _TagInputLayoutParentData;

      if (index < tagCount) {
        // Layout chip with loose constraints
        child.layout(BoxConstraints(maxWidth: maxWidth), parentUsesSize: true);

        final childSize = child.size;

        // Check if chip fits in current row
        if (x + childSize.width > maxWidth && x > 0) {
          // Center all children in the completed row vertically
          _centerChildrenVertically(currentRowChildren, y, maxHeightInRow);
          currentRowChildren.clear();

          x = 0;
          y += maxHeightInRow + runSpacing;
          maxHeightInRow = 0;
        }

        parentData.offset = Offset(x, y);
        currentRowChildren.add(child);
        x += childSize.width + spacing;
        maxHeightInRow = childSize.height > maxHeightInRow
            ? childSize.height
            : maxHeightInRow;
      } else {
        // Save text field for special layout handling
        textFieldChild = child;
      }

      child = parentData.nextSibling;
      index++;
    }

    // Now layout and position the text field
    if (textFieldChild != null) {
      final parentData =
          textFieldChild.parentData! as _TagInputLayoutParentData;
      final availableWidth = maxWidth - x;

      double textFieldX;
      double textFieldY;
      double textFieldWidth;

      // Determine text field position and width
      if (availableWidth >= minTextFieldWidth && x > 0) {
        // Fits in current row
        textFieldX = x;
        textFieldY = y;
        textFieldWidth = availableWidth;
      } else if (x == 0) {
        // Empty row, use full width
        textFieldX = 0;
        textFieldY = y;
        textFieldWidth = maxWidth;
      } else {
        // Center children in the completed row before moving to new row
        _centerChildrenVertically(currentRowChildren, y, maxHeightInRow);
        currentRowChildren.clear();

        // Move to new row
        y += maxHeightInRow + runSpacing;
        maxHeightInRow = 0;
        textFieldX = 0;
        textFieldY = y;
        textFieldWidth = maxWidth;
      }

      textFieldChild.layout(
        BoxConstraints(minWidth: minTextFieldWidth, maxWidth: textFieldWidth),
        parentUsesSize: true,
      );

      parentData.offset = Offset(textFieldX, textFieldY);
      currentRowChildren.add(textFieldChild);
      maxHeightInRow = textFieldChild.size.height > maxHeightInRow
          ? textFieldChild.size.height
          : maxHeightInRow;
    }

    // Center children in the last row vertically
    _centerChildrenVertically(currentRowChildren, y, maxHeightInRow);

    // Calculate final height
    final totalHeight = y + maxHeightInRow;
    size = constraints.constrain(Size(maxWidth, totalHeight));
  }

  /// Centers all children vertically within a row.
  void _centerChildrenVertically(
    List<RenderBox> children,
    double rowY,
    double rowHeight,
  ) {
    for (final child in children) {
      final parentData = child.parentData! as _TagInputLayoutParentData;
      final childHeight = child.size.height;
      final verticalOffset = (rowHeight - childHeight) / 2;
      parentData.offset = Offset(parentData.offset.dx, rowY + verticalOffset);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}
