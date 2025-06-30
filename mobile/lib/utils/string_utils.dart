// ABOUTME: String utility functions for safe operations and formatting
// ABOUTME: Provides safe substring operations and string truncation for logging

/// Utility functions for safe string operations
class StringUtils {
  /// Safely truncate a string to a maximum length for logging purposes
  /// Returns the string truncated to [maxLength] characters, or the full string if shorter
  static String safeTruncate(String str, int maxLength) {
    if (str.length <= maxLength) {
      return str;
    }
    return str.substring(0, maxLength);
  }
  
  /// Safe substring operation that won't throw RangeError
  /// Returns substring from [start] to [end], handling bounds automatically
  static String safeSubstring(String str, int start, [int? end]) {
    if (str.isEmpty) return '';
    
    // Clamp start to valid range
    start = start.clamp(0, str.length);
    
    // If no end specified, use string length
    end ??= str.length;
    
    // Clamp end to valid range
    end = end.clamp(start, str.length);
    
    return str.substring(start, end);
  }
  
  /// Format an ID for logging - safely truncates to 8 characters
  /// Commonly used pattern throughout the codebase for logging video/event IDs
  static String formatIdForLogging(String id) {
    return safeTruncate(id, 8);
  }
}