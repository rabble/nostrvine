# OpenVine Mobile App Refactoring Plan

## Executive Summary

This document outlines a comprehensive refactoring plan to address critical architectural and technical issues identified in the OpenVine mobile app code review. The plan follows an incremental approach over 6 weeks to minimize risk while delivering continuous improvements.

## Issues Overview

### Critical Issues
1. **Provider Complexity**: 41+ providers creating maintenance burden
2. **API Rate Limiting**: Missing protection against DoS attacks

### High Priority Issues
3. **Memory Leaks**: StreamControllers not properly disposed
4. **Technical Debt**: 26 files with TODO/FIXME comments

### Medium Priority Issues
5. **Security Warnings**: Web platform fallback lacks warnings
6. **Configuration**: Hardcoded values need externalization

### Low Priority Issues
7. **Code Cleanup**: Commented code removal
8. **Logging**: Incomplete error logging

## Refactoring Approach

### Strategy: Incremental Refactoring
- Maintain production stability
- Allow continued feature development
- Deliver value incrementally
- Enable learning between phases

## Phase 1: Critical Architecture (Weeks 1-2)

### Objectives
- Consolidate 41+ providers into 6 service groups
- Implement API rate limiting
- Establish monitoring infrastructure

### Provider Consolidation Plan

#### Service Groups Architecture
```
[Application Layer]
        |
   [6 Service Groups]
        |
┌───────────────┬───────────────┬───────────────┐
│ CoreServices  │ MediaServices │ NetworkServices│
├───────────────┼───────────────┼───────────────┤
│ • AuthService │ • VideoManager│ • ApiService   │
│ • KeyStorage  │ • UploadMgr   │ • WebSocket    │
│ • NostrService│ • DirectUpload│ • RateLimiter  │
└───────────────┴───────────────┴───────────────┘
┌───────────────┬───────────────┬───────────────┐
│ DataServices  │ UIServices    │FeatureServices│
├───────────────┼───────────────┼───────────────┤
│ • CacheService│ • ThemeService│ • SocialService│
│ • Storage     │ • Navigation  │ • CurationSvc  │
│ • ProfileCache│ • Preferences │ • VideoSharing │
└───────────────┴───────────────┴───────────────┘
```

### Week 1 Tasks

#### Day 1-2: Dependency Analysis
1. Create provider dependency graph using GraphViz
2. Identify circular dependencies
3. Document current provider relationships
4. Create migration priority list

#### Day 3-4: CoreServices Implementation
```dart
// lib/services/grouped/core_services.dart
class CoreServices extends ChangeNotifier {
  final AuthService _authService;
  final KeyStorageService _keyStorage;
  final INostrService _nostrService;
  
  CoreServices({
    required AuthService authService,
    required KeyStorageService keyStorage,
    required INostrService nostrService,
  }) : _authService = authService,
       _keyStorage = keyStorage,
       _nostrService = nostrService {
    // Set up inter-service listeners
    _authService.addListener(_onAuthChange);
    _nostrService.addListener(_onNostrChange);
  }
  
  // Expose unified interface
  AuthState get authState => _authService.authState;
  bool get hasKeys => _keyStorage.hasKeys();
  bool get isConnected => _nostrService.isInitialized;
  
  // Unified operations
  Future<void> initialize() async {
    await _keyStorage.initialize();
    await _authService.initialize();
    if (_authService.isAuthenticated) {
      await _nostrService.initialize();
    }
  }
  
  @override
  void dispose() {
    _authService.removeListener(_onAuthChange);
    _nostrService.removeListener(_onNostrChange);
    super.dispose();
  }
}
```

#### Day 5: Rate Limiter Implementation
```dart
// lib/services/network/rate_limiter.dart
class RateLimiter {
  final Map<String, List<DateTime>> _requests = {};
  final Map<String, RateLimitConfig> _configs = {
    '/v1/media/ready-events': RateLimitConfig(100, Duration(minutes: 1)),
    '/v1/media/request-upload': RateLimitConfig(10, Duration(minutes: 1)),
    '/v1/media/cleanup': RateLimitConfig(50, Duration(minutes: 1)),
  };
  
  Future<void> checkLimit(String endpoint) async {
    final config = _configs[endpoint] ?? 
      RateLimitConfig(200, Duration(minutes: 1)); // Default
    
    final now = DateTime.now();
    _requests[endpoint] ??= [];
    
    // Remove old requests outside window
    _requests[endpoint]!.removeWhere(
      (time) => now.difference(time) > config.window
    );
    
    if (_requests[endpoint]!.length >= config.maxRequests) {
      throw ApiException(
        'Rate limit exceeded. Try again in ${config.window.inMinutes} minutes',
        statusCode: 429,
      );
    }
    
    _requests[endpoint]!.add(now);
  }
}

class RateLimitConfig {
  final int maxRequests;
  final Duration window;
  
  const RateLimitConfig(this.maxRequests, this.window);
}
```

### Week 2 Tasks

#### Day 1-2: Migration Strategy
1. Create parallel provider structure in main.dart
2. Add feature flags for gradual migration
3. Update 3 pilot screens to use CoreServices
4. Measure performance impact

#### Day 3-4: Remaining Service Groups
```dart
// Create remaining 5 service groups following CoreServices pattern
// MediaServices: Combines video, upload, and media handling
// NetworkServices: Combines API, WebSocket, and rate limiting
// DataServices: Combines caching, storage, and persistence
// UIServices: Combines theme, navigation, and preferences
// FeatureServices: Combines social features and curation
```

#### Day 5: Testing & Rollback
1. Comprehensive integration tests
2. Performance benchmarking
3. Create rollback scripts
4. Document migration guide

### Success Metrics
- [ ] 6 service groups created and tested
- [ ] Provider initialization time < 100ms
- [ ] Rate limiting blocking excessive requests
- [ ] No functionality regression
- [ ] Performance maintained or improved

## Phase 2: Memory & Stability (Week 3)

### Objectives
- Fix all StreamController disposal issues
- Implement comprehensive error boundaries
- Add memory leak detection

### Implementation Plan

#### StreamController Fixes
```dart
// Pattern for proper disposal
class ServiceWithStreams extends ChangeNotifier {
  final _controller = StreamController<Event>.broadcast();
  bool _disposed = false;
  
  @override
  void dispose() {
    _disposed = true;
    try {
      if (!_controller.isClosed) {
        _controller.close();
      }
    } catch (e) {
      debugPrint('Error closing controller: $e');
    }
    super.dispose();
  }
  
  void addEvent(Event event) {
    if (!_disposed && !_controller.isClosed) {
      _controller.add(event);
    }
  }
}
```

#### Memory Leak Detection
1. Implement leak canary pattern
2. Add memory monitoring in debug builds
3. Create automated memory tests

### Success Metrics
- [ ] Zero memory leaks in 48-hour stress test
- [ ] All StreamControllers properly disposed
- [ ] Memory usage stable over time

## Phase 3: Technical Debt Reduction (Weeks 4-5)

### Objectives
- Reduce TODO/FIXME count by 50%
- Remove all commented code
- Improve error logging

### Systematic Approach

#### Week 4: Critical TODOs
1. Categorize all TODOs by severity
2. Address security-related TODOs first
3. Fix performance-related TODOs
4. Update functionality TODOs

#### Week 5: Code Cleanup
1. Remove all commented code
2. Standardize error logging
3. Update documentation
4. Add missing tests

### Success Metrics
- [ ] TODO count reduced by 50%
- [ ] All critical TODOs resolved
- [ ] Zero commented code blocks
- [ ] Consistent error logging pattern

## Phase 4: Configuration & Polish (Week 6)

### Objectives
- Externalize all configuration
- Add security warnings
- Final cleanup

### Implementation

#### Configuration Management
```dart
// lib/config/app_config.dart
class AppConfig {
  static String get nostrRelayUrl => 
    const String.fromEnvironment('NOSTR_RELAY_URL', 
      defaultValue: 'wss://vine.hol.is');
  
  static int get apiRateLimit =>
    const int.fromEnvironment('API_RATE_LIMIT',
      defaultValue: 100);
}
```

#### Security Warnings
```dart
// Add warnings for web platform
if (kIsWeb && !_useSecureStorage) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text('Security Notice'),
      content: Text('Your keys are stored in browser storage '
                   'which may be less secure than mobile storage.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('I Understand'),
        ),
      ],
    ),
  );
}
```

### Success Metrics
- [ ] All configuration externalized
- [ ] Security warnings implemented
- [ ] Code review completed
- [ ] Documentation updated

## Risk Management

### Mitigation Strategies
1. **Feature Flags**: Enable gradual rollout
2. **Rollback Scripts**: Quick reversion capability
3. **Performance Monitoring**: Catch regressions early
4. **Automated Testing**: Prevent functionality breaks

### Rollback Triggers
- Performance degradation > 5%
- Critical bug in production
- User complaints spike
- Memory usage increase > 20%

## Implementation Guidelines

### Code Review Process
- All changes require 2 reviewers
- Performance impact must be measured
- Tests required for all changes
- Documentation updates mandatory

### Testing Requirements
1. Unit tests for all new code
2. Integration tests for provider changes
3. Performance benchmarks before/after
4. Memory profiling for Phase 2

### Communication Plan
- Daily standups during refactoring
- Weekly progress reports
- Immediate escalation for blockers
- User communication for any impacts

## Success Criteria

### Overall Project Success
- [ ] Provider count reduced from 41+ to 6
- [ ] Zero memory leaks in production
- [ ] API protected by rate limiting
- [ ] Technical debt reduced by 50%
- [ ] Performance maintained or improved
- [ ] No increase in crash rate
- [ ] Developer productivity improved

## Conclusion

This refactoring plan addresses all critical issues while maintaining production stability. The incremental approach allows for continuous delivery of value and reduces risk. With proper execution and monitoring, the OpenVine app will have a more maintainable and scalable architecture.

## Appendix: Migration Patterns

### Provider Migration Pattern
```dart
// OLD: Direct provider usage
Provider.of<AuthService>(context).authenticate();

// NEW: Grouped service usage
Provider.of<CoreServices>(context).authenticate();
```

### Gradual Migration Example
```dart
// Feature flag controlled migration
Widget build(BuildContext context) {
  if (FeatureFlags.useGroupedProviders) {
    return Consumer<CoreServices>(
      builder: (context, core, child) => MyWidget(core),
    );
  } else {
    return Consumer<AuthService>(
      builder: (context, auth, child) => MyWidget(auth),
    );
  }
}
```