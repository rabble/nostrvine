# Pipeline Integration Tests

## 🎯 **Purpose**

These integration tests verify that the complete video upload → processing → publishing pipeline works correctly and handles failures gracefully. They're designed to catch the kinds of issues that only appear when services interact in real scenarios.

## 🧪 **Test Coverage**

### 1. **End-to-End Pipeline Flow** (`pipeline_integration_test.dart`)
- ✅ Complete upload → processing → publishing pipeline
- ✅ Service integration and state synchronization  
- ✅ Background polling and event detection
- ✅ Error handling and retry mechanisms
- ✅ Performance under concurrent load
- ✅ Service restart recovery

### 2. **Real File Operations** (`real_file_pipeline_test.dart`)
- ✅ Actual file I/O with MP4 video files
- ✅ File persistence across service restarts
- ✅ Large file handling (1MB+ files)
- ✅ Cross-service state synchronization
- ✅ Concurrent file operations

### 3. **Failure Scenarios** (`pipeline_failure_scenarios_test.dart`)
- ✅ Cloudinary upload failures
- ✅ Backend processing timeouts
- ✅ Nostr relay failures with retry logic
- ✅ Network timeouts and malformed responses
- ✅ Partial success handling (some relays fail)
- ✅ Service restart recovery
- ✅ Concurrent failure scenarios

### 4. **Test Framework** (`pipeline_test_factory.dart`)
- ✅ Reusable mock service factory
- ✅ Configurable failure scenarios
- ✅ Consistent test data generation
- ✅ Resource cleanup and management

## 🔧 **Key Features Tested**

### Pipeline Robustness
- **State Persistence**: Uploads survive app/service restarts
- **Error Recovery**: Graceful handling of network, server, and relay failures
- **Concurrent Safety**: Multiple uploads don't interfere with each other
- **Memory Management**: Proper cleanup of resources and connections

### Service Integration
- **UploadManager** ↔ **CloudinaryUploadService**: File upload coordination
- **VideoEventPublisher** ↔ **ApiService**: Backend polling and event detection
- **VideoEventPublisher** ↔ **NostrService**: Event broadcasting to relays
- **All Services** ↔ **NotificationService**: User status updates

### Real-World Scenarios
- **Network Failures**: Timeouts, connection drops, malformed responses
- **Backend Issues**: Processing failures, API errors, rate limiting
- **Nostr Network**: Relay failures, partial broadcasting, authentication issues
- **File System**: Large files, missing files, permission errors

## 🐛 **Issues Found During Testing**

The integration tests successfully identified several real issues:

1. **Resource Management**: Services need proper disposal order to avoid `ChangeNotifier` errors
2. **Hive Box Lifecycle**: Box management needs coordination between services
3. **Mock Setup**: Missing fallback values for complex types (`Event`, `NostrBroadcastResult`)
4. **Tag Duplication**: NIP-94 tag generation has some duplicate entries
5. **HTTP Client Lifecycle**: Need proper HTTP client management in test scenarios

## 🚀 **Usage**

### Running All Pipeline Tests
```bash
flutter test test/integration/
```

### Running Specific Test Categories
```bash
# End-to-end pipeline
flutter test test/integration/pipeline_integration_test.dart

# Real file operations  
flutter test test/integration/real_file_pipeline_test.dart

# Failure scenarios
flutter test test/integration/pipeline_failure_scenarios_test.dart

# Simple demo (good for debugging)
flutter test test/integration/simple_pipeline_demo_test.dart
```

### Creating Custom Test Scenarios
```dart
// Use the test factory for consistent setup
final stack = await PipelineTestFactory.createTestStack(
  testName: 'my_custom_test',
  config: PipelineTestConfig(
    scenario: PipelineTestScenario.success,
    networkDelay: Duration(milliseconds: 500),
    customMetadata: {'test_flag': true},
  ),
);

await stack.initialize();

try {
  final testFile = await PipelineTestFactory.createTestFile(
    tempDir, 
    'my_test.mp4'
  );
  
  final result = await stack.executeFullPipeline(testFile: testFile);
  
  expect(result.success, true);
} finally {
  await stack.dispose();
}
```

## 📊 **Test Results & Metrics**

The tests provide detailed metrics for each pipeline execution:

```dart
PipelineTestResult {
  success: true,
  duration_ms: 245,
  upload_created: true,
  marked_ready: true,
  publishing_triggered: true,
  final_status: UploadStatus.published,
  upload_id: "test-upload-123",
}
```

## ⚡ **Performance Benchmarks**

From test runs, typical performance expectations:

- **File Creation**: < 50ms for 1MB files
- **Upload State Creation**: < 100ms
- **State Transitions**: < 50ms each
- **Background Polling**: 30s active, 2min inactive
- **Concurrent Operations**: 5 uploads in < 500ms
- **Service Initialization**: < 200ms total

## 🛡️ **Error Handling Validation**

Tests verify that the pipeline handles these failure modes gracefully:

- ✅ **Network Timeouts**: Continue polling, don't crash
- ✅ **Upload Failures**: Mark as failed, preserve error message  
- ✅ **Processing Stuck**: Keep polling, don't retry failed uploads
- ✅ **Nostr Failures**: Track failures, allow manual retry
- ✅ **Partial Success**: Accept 1+ successful relay as success
- ✅ **Service Restart**: Recover uploads from persistence

## 🔄 **Continuous Integration**

These tests are designed to run in CI/CD environments and will catch:

- Integration regressions between services
- Performance degradations in the pipeline
- Error handling gaps that could crash the app
- State management issues that could lose user data
- Network resilience problems that affect reliability

## 📝 **Adding New Tests**

When adding new pipeline features:

1. **Add scenario to `PipelineTestScenario`** enum
2. **Implement mock behavior** in `PipelineTestFactory._setupMockBehaviors`
3. **Create focused test** in appropriate test file
4. **Update this README** with new coverage

The test framework is designed to make it easy to create realistic scenarios that match production conditions.