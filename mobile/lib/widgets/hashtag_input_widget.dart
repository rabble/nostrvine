// ABOUTME: Hashtag input widget with suggestions and visual hashtag chips
// ABOUTME: Provides intuitive interface for adding and managing hashtags with popular suggestions

import 'package:flutter/material.dart';

class HashtagInputWidget extends StatefulWidget {
  final List<String> hashtags;
  final ValueChanged<List<String>> onHashtagsChanged;
  final int maxHashtags;
  final List<String> suggestions;

  const HashtagInputWidget({
    super.key,
    required this.hashtags,
    required this.onHashtagsChanged,
    this.maxHashtags = 10,
    this.suggestions = const [
      'nostrvine',
      'vine',
      'nostr',
      'bitcoin',
      'decentralized',
      'shortform',
      'video',
      'social',
      'creator',
      'viral',
      'trending',
      'funny',
      'creative',
      'art',
      'music',
      'dance',
      'comedy',
      'tutorial',
      'tips',
      'lifestyle',
    ],
  });

  @override
  State<HashtagInputWidget> createState() => _HashtagInputWidgetState();
}

class _HashtagInputWidgetState extends State<HashtagInputWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;
  
  List<String> get _filteredSuggestions {
    if (_controller.text.isEmpty) {
      return widget.suggestions.take(6).toList();
    }
    
    final query = _controller.text.toLowerCase();
    return widget.suggestions
        .where((tag) => tag.toLowerCase().contains(query))
        .where((tag) => !widget.hashtags.contains(tag))
        .take(8)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _showSuggestions = _focusNode.hasFocus;
    });
  }

  void _addHashtag(String hashtag) {
    final cleanTag = hashtag.trim().toLowerCase().replaceAll('#', '');
    
    if (cleanTag.isEmpty || 
        widget.hashtags.contains(cleanTag) || 
        widget.hashtags.length >= widget.maxHashtags) {
      return;
    }

    // Validate hashtag format (alphanumeric and underscores only)
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(cleanTag)) {
      return;
    }

    final newHashtags = List<String>.from(widget.hashtags)..add(cleanTag);
    widget.onHashtagsChanged(newHashtags);
    
    _controller.clear();
  }

  void _removeHashtag(String hashtag) {
    final newHashtags = List<String>.from(widget.hashtags)..remove(hashtag);
    widget.onHashtagsChanged(newHashtags);
  }

  void _onSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _addHashtag(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hashtag Chips
        if (widget.hashtags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.hashtags.map((hashtag) => _buildHashtagChip(hashtag)).toList(),
          ),
          const SizedBox(height: 12),
        ],
        
        // Input Field
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: widget.hashtags.isEmpty 
                ? 'Add hashtags to help people find your video...'
                : 'Add more hashtags...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.tag, color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.add, color: Colors.purple),
                    onPressed: () => _onSubmitted(_controller.text),
                  )
                : null,
          ),
          onSubmitted: _onSubmitted,
          onChanged: (value) {
            setState(() {});
          },
        ),
        
        // Suggestions
        if (_showSuggestions && _filteredSuggestions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            _controller.text.isEmpty ? 'Popular hashtags:' : 'Suggestions:',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _filteredSuggestions
                .map((suggestion) => _buildSuggestionChip(suggestion))
                .toList(),
          ),
        ],
        
        // Helper Text
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${widget.hashtags.length}/${widget.maxHashtags} hashtags',
              style: TextStyle(
                color: widget.hashtags.length >= widget.maxHashtags 
                    ? Colors.orange 
                    : Colors.grey,
                fontSize: 12,
              ),
            ),
            const Spacer(),
            if (widget.hashtags.length >= widget.maxHashtags)
              const Text(
                'Maximum reached',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildHashtagChip(String hashtag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$hashtag',
            style: const TextStyle(
              color: Colors.purple,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeHashtag(hashtag),
            child: const Icon(
              Icons.close,
              size: 16,
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String suggestion) {
    return GestureDetector(
      onTap: () => _addHashtag(suggestion),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[600]!),
        ),
        child: Text(
          '#$suggestion',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}