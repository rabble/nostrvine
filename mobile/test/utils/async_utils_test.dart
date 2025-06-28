// ABOUTME: Comprehensive tests for AsyncUtils class and proper async patterns
// ABOUTME: Ensures the new async utilities work correctly and replace timing hacks properly

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/async_utils.dart';

void main() {
  group('AsyncUtils', () {
    group('waitForCondition', () {
      test('should complete when condition becomes true', () async {
        bool condition = false;
        
        // Start the wait
        final waitFuture = AsyncUtils.waitForCondition(
          condition: () => condition,
          timeout: const Duration(seconds: 2),
          checkInterval: const Duration(milliseconds: 50),
        );
        
        // Set condition to true after delay
        Timer(const Duration(milliseconds: 100), () {
          condition = true;
        });
        
        final result = await waitFuture;
        expect(result, true);
      });
      
      test('should timeout if condition never becomes true', () async {
        final result = await AsyncUtils.waitForCondition(
          condition: () => false,
          timeout: const Duration(milliseconds: 100),
          checkInterval: const Duration(milliseconds: 10),
        );
        
        expect(result, false);
      });
      
      test('should handle condition exceptions', () async {
        expect(
          () => AsyncUtils.waitForCondition(
            condition: () => throw Exception('Test error'),
            timeout: const Duration(milliseconds: 100),
          ),
          throwsException,
        );
      });
      
      test('should return immediately if condition is already true', () async {
        final stopwatch = Stopwatch()..start();
        
        final result = await AsyncUtils.waitForCondition(
          condition: () => true,
          timeout: const Duration(seconds: 1),
        );
        
        stopwatch.stop();
        expect(result, true);
        expect(stopwatch.elapsedMilliseconds, lessThan(50));
      });
    });
    
    group('createCompletionHandler', () {
      test('should create a completer that can be completed externally', () async {
        final completer = AsyncUtils.createCompletionHandler<String>();
        
        // Complete from external source
        Timer(const Duration(milliseconds: 50), () {
          completer.complete('test result');
        });
        
        final result = await completer.future;
        expect(result, 'test result');
      });
      
      test('should handle errors', () async {
        final completer = AsyncUtils.createCompletionHandler<String>();
        
        Timer(const Duration(milliseconds: 50), () {
          completer.completeError(Exception('Test error'));
        });
        
        expect(() => completer.future, throwsException);
      });
    });
    
    group('retryWithBackoff', () {
      test('should succeed on first attempt', () async {
        int attempts = 0;
        
        final result = await AsyncUtils.retryWithBackoff(
          operation: () async {
            attempts++;
            return 'success';
          },
          maxRetries: 3,
          baseDelay: const Duration(milliseconds: 10),
        );
        
        expect(result, 'success');
        expect(attempts, 1);
      });
      
      test('should retry with exponential backoff', () async {
        int attempts = 0;
        final attemptTimes = <DateTime>[];
        
        try {
          await AsyncUtils.retryWithBackoff(
            operation: () async {
              attempts++;
              attemptTimes.add(DateTime.now());
              
              if (attempts < 3) {
                throw Exception('Attempt $attempts failed');
              }
              return 'success';
            },
            maxRetries: 3,
            baseDelay: const Duration(milliseconds: 100),
            backoffMultiplier: 2.0,
          );
        } catch (e) {
          // Expected for this test
        }
        
        expect(attempts, 3);
        expect(attemptTimes.length, 3);
        
        // Check that delays increased (with some tolerance for timing)
        if (attemptTimes.length >= 2) {
          final firstDelay = attemptTimes[1].difference(attemptTimes[0]);
          expect(firstDelay.inMilliseconds, greaterThan(90)); // ~100ms
        }
      });
      
      test('should respect maxRetries', () async {
        int attempts = 0;
        
        try {
          await AsyncUtils.retryWithBackoff(
            operation: () async {
              attempts++;
              throw Exception('Always fails');
            },
            maxRetries: 2,
            baseDelay: const Duration(milliseconds: 10),
          );
        } catch (e) {
          // Expected to fail
        }
        
        expect(attempts, 3); // Initial attempt + 2 retries
      });
      
      test('should respect retryWhen condition', () async {
        int attempts = 0;
        
        expect(
          () => AsyncUtils.retryWithBackoff(
            operation: () async {
              attempts++;
              throw Exception('Non-retriable error');
            },
            maxRetries: 3,
            baseDelay: const Duration(milliseconds: 10),
            retryWhen: (error) => false, // Never retry
          ),
          throwsException,
        );
        
        expect(attempts, 1); // Only initial attempt
      });
      
      test('should respect maxDelay', () async {
        int attempts = 0;
        final attemptTimes = <DateTime>[];
        
        try {
          await AsyncUtils.retryWithBackoff(
            operation: () async {
              attempts++;
              attemptTimes.add(DateTime.now());
              throw Exception('Always fails');
            },
            maxRetries: 4,
            baseDelay: const Duration(milliseconds: 100),
            maxDelay: const Duration(milliseconds: 150),
            backoffMultiplier: 10.0, // Would normally create huge delays
          );
        } catch (e) {
          // Expected
        }
        
        // Verify that delays didn't exceed maxDelay
        for (int i = 1; i < attemptTimes.length; i++) {
          final delay = attemptTimes[i].difference(attemptTimes[i - 1]);
          expect(delay.inMilliseconds, lessThan(200)); // Allow some tolerance
        }
      });
    });
    
    group('waitForStreamValue', () {
      test('should complete when stream emits matching value', () async {
        final controller = StreamController<int>();
        
        // Start waiting
        final waitFuture = AsyncUtils.waitForStreamValue(
          stream: controller.stream,
          predicate: (value) => value > 5,
          timeout: const Duration(seconds: 1),
        );
        
        // Emit values
        Timer(const Duration(milliseconds: 50), () {
          controller.add(3);
          controller.add(7); // This should match
        });
        
        final result = await waitFuture;
        expect(result, 7);
        
        await controller.close();
      });
      
      test('should timeout if no matching value is emitted', () async {
        final controller = StreamController<int>();
        
        expect(
          () => AsyncUtils.waitForStreamValue(
            stream: controller.stream,
            predicate: (value) => value > 10,
            timeout: const Duration(milliseconds: 100),
          ),
          throwsA(isA<TimeoutException>()),
        );
        
        // Emit non-matching values
        controller.add(1);
        controller.add(2);
        
        await controller.close();
      });
      
      test('should handle stream errors', () async {
        final controller = StreamController<int>();
        
        final waitFuture = AsyncUtils.waitForStreamValue(
          stream: controller.stream,
          predicate: (value) => value > 5,
          timeout: const Duration(seconds: 1),
        );
        
        Timer(const Duration(milliseconds: 50), () {
          controller.addError(Exception('Stream error'));
          controller.close();
        });
        
        expect(() => waitFuture, throwsException);
      });
    });
    
    group('debounce', () {
      test('should debounce rapid calls', () async {
        int callCount = 0;
        
        final debouncedFunction = AsyncUtils.debounce(
          operation: () => callCount++,
          delay: const Duration(milliseconds: 100),
        );
        
        // Make rapid calls
        debouncedFunction();
        debouncedFunction();
        debouncedFunction();
        
        // Should not execute yet
        expect(callCount, 0);
        
        // Wait for debounce delay
        await Future.delayed(const Duration(milliseconds: 150));
        
        // Should have executed only once
        expect(callCount, 1);
      });
    });
    
    group('throttle', () {
      test('should throttle rapid calls', () async {
        int callCount = 0;
        
        final throttledFunction = AsyncUtils.throttle(
          operation: () => callCount++,
          interval: const Duration(milliseconds: 100),
        );
        
        // First call should execute immediately
        throttledFunction();
        expect(callCount, 1);
        
        // Rapid subsequent calls should be throttled
        throttledFunction();
        throttledFunction();
        expect(callCount, 1);
        
        // After interval, next call should execute
        await Future.delayed(const Duration(milliseconds: 150));
        throttledFunction();
        expect(callCount, 2);
      });
    });
  });
  
  group('AsyncInitialization mixin', () {
    late TestAsyncClass testObject;
    
    setUp(() {
      testObject = TestAsyncClass();
    });
    
    test('should track initialization state', () {
      expect(testObject.isInitialized, false);
      
      testObject.startInit();
      expect(testObject.isInitialized, false);
      
      testObject.completeInit();
      expect(testObject.isInitialized, true);
    });
    
    test('should complete initialization future', () async {
      testObject.startInit();
      
      Timer(const Duration(milliseconds: 50), () {
        testObject.completeInit();
      });
      
      await testObject.waitForInitialization();
      expect(testObject.isInitialized, true);
    });
    
    test('should handle initialization failure', () async {
      testObject.startInit();
      
      Timer(const Duration(milliseconds: 50), () {
        testObject.failInit(Exception('Init failed'));
      });
      
      expect(
        () => testObject.waitForInitialization(),
        throwsException,
      );
    });
    
    test('should timeout if initialization takes too long', () async {
      testObject.startInit();
      
      expect(
        () => testObject.waitForInitialization(
          timeout: const Duration(milliseconds: 100),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
    
    test('should return immediately if already initialized', () async {
      testObject.startInit();
      testObject.completeInit();
      
      final stopwatch = Stopwatch()..start();
      await testObject.waitForInitialization();
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}

/// Test class that uses AsyncInitialization mixin
class TestAsyncClass with AsyncInitialization {
  void startInit() => startInitialization();
  void completeInit() => completeInitialization();
  void failInit(Object error) => failInitialization(error);
}