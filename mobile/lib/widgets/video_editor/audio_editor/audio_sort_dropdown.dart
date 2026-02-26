import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Sort options for the audio/sound list.
enum AudioSortOption {
  newest('Newest'),
  longest('Longest'),
  shortest('Shortest')
  ;

  const AudioSortOption(this.label);
  final String label;
}

/// A dropdown button for selecting audio sort order with animations.
class AudioSortDropdown extends StatefulWidget {
  const AudioSortDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final AudioSortOption value;
  final ValueChanged<AudioSortOption> onChanged;

  @override
  State<AudioSortDropdown> createState() => _AudioSortDropdownState();
}

class _AudioSortDropdownState extends State<AudioSortDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isOpen = true;
    _animationController.forward();
  }

  Future<void> _closeDropdown() async {
    await _animationController.reverse();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOpen = false;
  }

  void _selectOption(AudioSortOption option) {
    widget.onChanged(option);
    _closeDropdown();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject()! as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => _DropdownOverlay(
        layerLink: _layerLink,
        buttonSize: size,
        slideAnimation: _slideAnimation,
        fadeAnimation: _fadeAnimation,
        selectedOption: widget.value,
        onOptionSelected: _selectOption,
        onClose: _closeDropdown,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: _DropdownButton(label: widget.value.label, onTap: _toggleDropdown),
    );
  }
}

class _DropdownOverlay extends StatelessWidget {
  const _DropdownOverlay({
    required this.layerLink,
    required this.buttonSize,
    required this.slideAnimation,
    required this.fadeAnimation,
    required this.selectedOption,
    required this.onOptionSelected,
    required this.onClose,
  });

  final LayerLink layerLink;
  final Size buttonSize;
  final Animation<Offset> slideAnimation;
  final Animation<double> fadeAnimation;
  final AudioSortOption selectedOption;
  final ValueChanged<AudioSortOption> onOptionSelected;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _DropdownBackdrop(onClose: onClose),
        Positioned(
          width: 240,
          child: CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, buttonSize.height + 4),
            child: SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Material(
                  type: .transparency,
                  child: _DropdownMenu(
                    selectedOption: selectedOption,
                    onOptionSelected: onOptionSelected,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DropdownBackdrop extends StatelessWidget {
  const _DropdownBackdrop({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(onTap: onClose, behavior: .opaque),
    );
  }
}

class _DropdownButton extends StatelessWidget {
  const _DropdownButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Sort by $label. Tap to change sort order',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const .symmetric(vertical: 12, horizontal: 16),
          child: Row(
            spacing: 8,
            mainAxisSize: .min,
            children: [
              SvgPicture.asset(
                'assets/icon/funnel_simple.svg',
                width: 24,
                height: 24,
                colorFilter: const .mode(VineTheme.primary, .srcIn),
              ),
              Text(
                label,
                style: VineTheme.titleMediumFont(fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownMenu extends StatelessWidget {
  const _DropdownMenu({
    required this.selectedOption,
    required this.onOptionSelected,
  });

  final AudioSortOption selectedOption;
  final ValueChanged<AudioSortOption> onOptionSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const .symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: .circular(16),
        border: .all(color: VineTheme.outlineMuted, width: 2),
        boxShadow: const [BoxShadow(color: VineTheme.scrim15, blurRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: .circular(14),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          children: [
            for (final option in AudioSortOption.values)
              _DropdownMenuItem(
                label: option.label,
                isSelected: option == selectedOption,
                onTap: () => onOptionSelected(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _DropdownMenuItem extends StatelessWidget {
  const _DropdownMenuItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .all(16),
          decoration: BoxDecoration(
            color: isSelected ? VineTheme.primary.withAlpha(25) : null,
            border: const Border(
              top: BorderSide(color: VineTheme.outlineMuted),
              bottom: BorderSide(color: VineTheme.outlineMuted),
            ),
          ),
          child: Text(
            label,
            style: VineTheme.titleMediumFont(fontSize: 16, height: 1.5)
                .copyWith(
                  color: isSelected ? VineTheme.primary : VineTheme.onSurface,
                ),
          ),
        ),
      ),
    );
  }
}
