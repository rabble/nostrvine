// ABOUTME: Automated migration script to convert debugPrint calls to UnifiedLogger
// ABOUTME: Handles pattern recognition, import injection, and systematic refactoring

import 'dart:io';

/// Migration categories mapping file paths to appropriate log categories
const Map<String, String> pathToCategoryMap = {
  'lib/services/nostr_': 'LogCategory.relay',
  'lib/services/video_': 'LogCategory.video', 
  'lib/services/upload_': 'LogCategory.video',
  'lib/services/camera': 'LogCategory.video',
  'lib/services/auth': 'LogCategory.auth',
  'lib/services/key': 'LogCategory.auth',
  'lib/services/secure': 'LogCategory.auth',
  'lib/services/api': 'LogCategory.api',
  'lib/services/storage': 'LogCategory.storage',
  'lib/services/profile': 'LogCategory.storage',
  'lib/screens/': 'LogCategory.ui',
  'lib/widgets/': 'LogCategory.ui',
  'lib/providers/': 'LogCategory.ui',
  'lib/main.dart': 'LogCategory.system',
  'lib/utils/': 'LogCategory.system',
};

/// Log level patterns based on emoji and content
const Map<String, String> logLevelPatterns = {
  // Error patterns
  r'❌|Error|Failed|Exception|Crash': 'Log.error',
  
  // Warning patterns  
  r'⚠️|Warning|Warn|Deprecated|Retry|Skipping|Missing': 'Log.warning',
  
  // Info patterns (important state changes)
  r'✅|Success|Completed|Connected|Initialized|Started|Stopped|Created|Found': 'Log.info',
  
  // Debug patterns (detailed operational info)
  r'🔍|🔄|📡|🎬|🎥|📥|🎯|Creating|Loading|Processing|Handling|Switching|Checking': 'Log.debug',
  
  // Verbose patterns (very detailed tracing)
  r'📝|🏷️|🖼️|👤|- Authors:|- Hashtags:|- Since:|- Until:|- Limit:|Detailed|Trace': 'Log.verbose',
};

String determineLogCategory(String filePath) {
  for (final entry in pathToCategoryMap.entries) {
    if (filePath.contains(entry.key)) {
      return entry.value;
    }
  }
  return 'LogCategory.system'; // Default fallback
}

String determineLogLevel(String logMessage) {
  for (final entry in logLevelPatterns.entries) {
    if (RegExp(entry.key, caseSensitive: false).hasMatch(logMessage)) {
      return entry.value;
    }
  }
  return 'Log.debug'; // Default fallback for debugPrint
}

String extractServiceName(String filePath) {
  final fileName = filePath.split('/').last.replaceAll('.dart', '');
  
  // Convert snake_case to PascalCase for service names
  return fileName.split('_')
      .map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '')
      .join('');
}

String cleanupLogMessage(String message) {
  // Remove emoji prefixes since they'll be in the log format
  final emojiPattern = RegExp(r'^[✅❌⚠️🔍🔄📡🎬🎥📥🎯📝🏷️🖼️👤📢📋📊🚀⏹️⏸️📭📬🚫🎨🔧]+\s*');
  return message.replaceFirst(emojiPattern, '');
}

/// Migration implementation for a single file
Future<bool> migrateFile(String filePath) async {
  final file = File(filePath);
  if (!file.existsSync()) return false;
  
  final content = await file.readAsString();
  final lines = content.split('\n');
  final newLines = <String>[];
  
  bool hasDebugPrint = false;
  bool hasUnifiedLoggerImport = false;
  
  // Check if file already has UnifiedLogger import
  for (final line in lines) {
    if (line.contains("import '../utils/unified_logger.dart'") || 
        line.contains("import 'package:openvine/utils/unified_logger.dart'")) {
      hasUnifiedLoggerImport = true;
      break;
    }
  }
  
  final category = determineLogCategory(filePath);
  final serviceName = extractServiceName(filePath);
  
  for (int i = 0; i < lines.length; i++) {
    String line = lines[i];
    
    // Add import after existing imports
    if (!hasUnifiedLoggerImport && 
        line.trim().startsWith('import ') && 
        (i + 1 >= lines.length || !lines[i + 1].trim().startsWith('import '))) {
      newLines.add(line);
      newLines.add("import '../utils/unified_logger.dart';");
      hasUnifiedLoggerImport = true;
      continue;
    }
    
    // Convert debugPrint calls
    if (line.contains('debugPrint(')) {
      hasDebugPrint = true;
      final regex = RegExp(r"debugPrint\('([^']+)'\)");
      final match = regex.firstMatch(line);
      
      if (match != null) {
        final originalMessage = match.group(1)!;
        final cleanMessage = cleanupLogMessage(originalMessage);
        final logLevel = determineLogLevel(originalMessage);
        final indentation = line.substring(0, line.indexOf('debugPrint('));
        
        // Create new log call
        final newLogCall = "$indentation$logLevel('$cleanMessage', name: '$serviceName', category: $category);";
        newLines.add(newLogCall);
        continue;
      }
    }
    
    newLines.add(line);
  }
  
  if (hasDebugPrint) {
    await file.writeAsString(newLines.join('\n'));
    print('✅ Migrated $filePath: ${serviceName} → ${category}');
    return true;
  }
  
  return false;
}

void main() async {
  print('🚀 Starting debugPrint to UnifiedLogger migration...');
  
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('❌ lib directory not found. Run from project root.');
    return;
  }
  
  final dartFiles = libDir
      .listSync(recursive: true)
      .where((entity) => entity is File && entity.path.endsWith('.dart'))
      .map((entity) => entity.path)
      .toList();
  
  int migratedFiles = 0;
  
  for (final filePath in dartFiles) {
    if (await migrateFile(filePath)) {
      migratedFiles++;
    }
  }
  
  print('✅ Migration complete!');
  print('📊 Migrated $migratedFiles files out of ${dartFiles.length} total Dart files');
  print('');
  print('🔧 Next steps:');
  print('1. Run `flutter analyze` to check for any issues');
  print('2. Test the app to ensure logging works correctly');
  print('3. Adjust log levels in main.dart if needed');
  print('4. Use DebugLoggerConfig helpers for debugging specific areas');
}