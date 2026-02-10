// .claude/check_duplicates.dart
import 'dart:io';

void main() {
  final classPattern = RegExp(r'class\s+(\w+)');
  final classes = <String, List<String>>{};
  
  // Scan for duplicate-looking class names
  Directory('mobile/lib').listSync(recursive: true).forEach((file) {
    if (file.path.endsWith('.dart')) {
      final content = File(file.path).readAsStringSync();
      final matches = classPattern.allMatches(content);
      
      for (final match in matches) {
        final className = match.group(1)!;
        classes.putIfAbsent(className, () => []).add(file.path);
      }
    }
  });
  
  // Find similar class names
  final suspicious = <String>[];
  classes.forEach((name, files) {
    // Check for variants like UserProfile, UserProfilePure, UserProfileWidget
    classes.forEach((otherName, otherFiles) {
      if (name != otherName && 
          (name.contains(otherName) || otherName.contains(name))) {
        suspicious.add('⚠️  Similar classes: $name vs $otherName');
      }
    });
  });
  
  if (suspicious.isNotEmpty) {
    print('Found potentially duplicate classes:');
    suspicious.toSet().forEach(print);
    exit(1);
  }
}