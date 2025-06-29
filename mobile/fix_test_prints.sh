#!/bin/bash
# ABOUTME: Script to fix print statements in test files by replacing them with Log statements
# ABOUTME: Adds import for unified_logger and replaces print() with Log.debug()

# Function to fix prints in a file
fix_file() {
    local file="$1"
    echo "Processing: $file"
    
    # Check if unified_logger import already exists
    if ! grep -q "import.*unified_logger.dart" "$file"; then
        # Add import after the first import statement
        sed -i '' "/^import/a\\
import 'package:openvine/utils/unified_logger.dart';
" "$file"
    fi
    
    # Replace print( with Log.debug(
    sed -i '' 's/print(/Log.debug(/g' "$file"
    
    echo "Fixed: $file"
}

# Fix specific files with most prints
fix_file "test_nostr_sdk_auth_issue.dart"
fix_file "integration_test/thumbnail_integration_test.dart"
fix_file "test/manual_thumbnail_test.dart"
fix_file "test/load_testing/performance_benchmarks.dart"
fix_file "test_thumbnail_end_to_end.dart"
fix_file "test_improved_video_parsing.dart"
fix_file "test/services/direct_upload_service_integration_test.dart"
fix_file "test_video_event_service_debug.dart"
fix_file "test_direct_nostr_v2.dart"
fix_file "integration_test/nip42_auth_integration_test.dart"
fix_file "test/integration/simple_pipeline_demo_test.dart"
fix_file "test_nostr_sdk.dart"
fix_file "test/debug_relay_auth.dart"
fix_file "test/test_relay_subscriptions.dart"
fix_file "test/services/nip42_auth_test.dart"
fix_file "test/integration/subscription_fix_test.dart"
fix_file "test/integration/real_file_pipeline_test.dart"
fix_file "test/integration/pipeline_integration_test.dart"
fix_file "test/integration/nostr_service_v2_integration_test.dart"

echo "All files processed!"