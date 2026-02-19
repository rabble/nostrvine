import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Sort options for the audio/sound list.
enum AudioSortOption {
  trending('Trending'),
  mostPopular('Most Popular'),
  newest('Newest'),
  longest('Longest'),
  shortest('Shortest');

  const AudioSortOption(this.label);
  final String label;
}

/// A dropdown button for selecting audio sort order.
class AudioSortDropdown extends StatefulWidget {
  const AudioSortDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AudioSortOption value;
  final ValueChanged<AudioSortOption> onChanged;

  @override
  State<AudioSortDropdown> createState() => _AudioSortDropdownState();
}

class _AudioSortDropdownState extends State<AudioSortDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

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
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  void _selectOption(AudioSortOption option) {
    widget.onChanged(option);
    _closeDropdown();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject()! as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop to close dropdown when tapping outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.opaque,
              child: const ColoredBox(color: Colors.transparent),
            ),
          ),
          // Dropdown menu
          Positioned(
            width: 200,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                color: Colors.transparent,
                child: _DropdownMenu(
                  selectedOption: widget.value,
                  onOptionSelected: _selectOption,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _closeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: _DropdownButton(label: widget.value.label, isOpen: _isOpen),
      ),
    );
  }
}

class _DropdownButton extends StatelessWidget {
  const _DropdownButton({required this.label, required this.isOpen});

  final String label;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 1,
            offset: Offset(1, 1),
          ),
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 0.6,
            offset: Offset(0.4, 0.4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icon/funnel_simple.svg',
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(VineTheme.vineGreen, BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: VineTheme.titleMediumFont(fontSize: 16, height: 1.5),
          ),
        ],
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
      width: 200,
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VineTheme.outlineMuted, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: AudioSortOption.values.map((option) {
            final isSelected = option == selectedOption;
            return _DropdownMenuItem(
              label: option.label,
              isSelected: isSelected,
              onTap: () => onOptionSelected(option),
            );
          }).toList(),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? VineTheme.vineGreen.withAlpha(25) : null,
          border: Border(
            top: BorderSide(color: VineTheme.outlineMuted),
            bottom: BorderSide(color: VineTheme.outlineMuted),
          ),
        ),
        child: Text(
          label,
          style: VineTheme.titleMediumFont(fontSize: 16, height: 1.5).copyWith(
            color: isSelected ? VineTheme.vineGreen : VineTheme.onSurface,
          ),
        ),
      ),
    );
  }
}
