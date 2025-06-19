// ABOUTME: Reusable search bar widget with typing suggestions and clear functionality
// ABOUTME: Provides consistent search UI across different screens with debounced input

import 'package:flutter/material.dart';

class SearchBarWidget extends StatefulWidget {
  final String? hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function()? onClear;
  final TextEditingController? controller;
  final bool autofocus;
  final bool showClearButton;
  final Widget? leadingIcon;
  final List<Widget>? actions;

  const SearchBarWidget({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.autofocus = false,
    this.showClearButton = true,
    this.leadingIcon,
    this.actions,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _clearText() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Leading icon (search icon by default)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: widget.leadingIcon ?? 
                const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 20,
                ),
          ),
          
          // Text input
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: widget.autofocus,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: widget.onSubmitted,
            ),
          ),
          
          // Clear button
          if (_hasText && widget.showClearButton)
            IconButton(
              icon: const Icon(
                Icons.clear,
                color: Colors.grey,
                size: 20,
              ),
              onPressed: _clearText,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          
          // Additional actions
          if (widget.actions != null) ...widget.actions!,
          
          // Right padding if no actions
          if (widget.actions == null)
            const SizedBox(width: 16),
        ],
      ),
    );
  }
}

/// Specialized search bar for the main search screen
class MainSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final Function(String) onSubmitted;
  final VoidCallback onClear;

  const MainSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Back button
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            
            const SizedBox(width: 8),
            
            // Search bar
            Expanded(
              child: SearchBarWidget(
                controller: controller,
                hintText: 'Search users, videos, hashtags...',
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                onClear: onClear,
                autofocus: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact search bar for embedding in other screens
class CompactSearchBar extends StatelessWidget {
  final String? hintText;
  final Function(String)? onChanged;
  final Function()? onTap;
  final bool enabled;

  const CompactSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey[700]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: Colors.grey[500],
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hintText!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}