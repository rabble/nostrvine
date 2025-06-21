// ABOUTME: PerformanceOptimizer - Advanced performance optimizations for Workers
// ABOUTME: Implements parallel processing, request coalescing, circuit breakers, and memory management

import { Env, ExecutionContext } from './types';

interface Task<T> {
  id: string;
  execute: () => Promise<T>;
  priority?: number;
}

interface CircuitBreakerOptions {
  failureThreshold: number;    // Number of failures before opening
  resetTimeout: number;        // Ms to wait before trying again
  monitoringPeriod: number;    // Ms window for counting failures
}

interface MemoryStats {
  used: number;
  limit: number;
  percentage: number;
  timestamp: number;
}

type CircuitState = 'CLOSED' | 'OPEN' | 'HALF_OPEN';

/**
 * Request coalescing to prevent duplicate operations
 */
export class RequestCoalescer<T> {
  private inFlightRequests = new Map<string, Promise<T>>();
  
  async coalesce(key: string, operation: () => Promise<T>): Promise<T> {
    const existing = this.inFlightRequests.get(key);
    if (existing) {
      return existing;
    }

    const promise = operation().finally(() => {
      this.inFlightRequests.delete(key);
    });

    this.inFlightRequests.set(key, promise);
    return promise;
  }

  getPendingCount(): number {
    return this.inFlightRequests.size;
  }
}

/**
 * Circuit breaker pattern for resilience
 */
export class CircuitBreaker {
  private state: CircuitState = 'CLOSED';
  private failures = 0;
  private lastFailureTime = 0;
  private successCount = 0;
  private lastStateChange = Date.now();

  constructor(private options: CircuitBreakerOptions) {}

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastStateChange > this.options.resetTimeout) {
        this.state = 'HALF_OPEN';
        this.lastStateChange = Date.now();
      } else {
        throw new Error('Circuit breaker is OPEN');
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failures = 0;
    if (this.state === 'HALF_OPEN') {
      this.successCount++;
      if (this.successCount >= 3) { // Require 3 successes to fully close
        this.state = 'CLOSED';
        this.successCount = 0;
        this.lastStateChange = Date.now();
      }
    }
  }

  private onFailure(): void {
    this.failures++;
    this.lastFailureTime = Date.now();
    
    if (this.state === 'HALF_OPEN') {
      this.state = 'OPEN';
      this.lastStateChange = Date.now();
      this.successCount = 0;
    } else if (this.failures >= this.options.failureThreshold) {
      const timeSinceFirstFailure = Date.now() - (this.lastFailureTime - this.options.monitoringPeriod);
      if (timeSinceFirstFailure <= this.options.monitoringPeriod) {
        this.state = 'OPEN';
        this.lastStateChange = Date.now();
      } else {
        this.failures = 1; // Reset counter if outside monitoring period
      }
    }
  }

  getState(): CircuitState {
    return this.state;
  }

  getStats() {
    return {
      state: this.state,
      failures: this.failures,
      lastStateChange: this.lastStateChange,
      timeSinceLastFailure: this.lastFailureTime ? Date.now() - this.lastFailureTime : null
    };
  }
}

/**
 * Parallel processor with concurrency control
 */
export class ParallelProcessor {
  private activeOperations = 0;
  
  constructor(private maxConcurrency: number = 6) {}

  /**
   * Process tasks in parallel with concurrency limit
   */
  async processParallel<T>(tasks: Task<T>[]): Promise<T[]> {
    const results: T[] = new Array(tasks.length);
    const errors: Error[] = [];
    
    // Sort by priority if specified
    const sortedTasks = [...tasks].sort((a, b) => (b.priority || 0) - (a.priority || 0));
    
    // Process in chunks based on concurrency limit
    for (let i = 0; i < sortedTasks.length; i += this.maxConcurrency) {
      const chunk = sortedTasks.slice(i, i + this.maxConcurrency);
      const chunkPromises = chunk.map(async (task, index) => {
        const originalIndex = tasks.findIndex(t => t.id === task.id);
        try {
          this.activeOperations++;
          results[originalIndex] = await task.execute();
        } catch (error) {
          errors.push(error as Error);
          results[originalIndex] = null as any;
        } finally {
          this.activeOperations--;
        }
      });
      
      await Promise.all(chunkPromises);
    }
    
    if (errors.length > 0) {
      console.error(`${errors.length} operations failed during parallel processing`);
    }
    
    return results;
  }

  /**
   * Process with memory limit awareness
   */
  async processWithMemoryLimit<T>(
    tasks: Task<T>[], 
    memoryLimitMB: number = 100
  ): Promise<T[]> {
    const results: T[] = [];
    const memoryMonitor = new MemoryMonitor();
    
    for (const task of tasks) {
      // Check memory before processing
      const stats = memoryMonitor.getStats();
      if (stats.percentage > 0.8) { // 80% threshold
        console.warn('Memory usage high, waiting before processing next task');
        await new Promise(resolve => setTimeout(resolve, 100));
      }
      
      if (stats.used > memoryLimitMB * 1024 * 1024) {
        throw new Error(`Memory limit exceeded: ${stats.used / 1024 / 1024}MB used`);
      }
      
      results.push(await task.execute());
    }
    
    return results;
  }

  getActiveOperations(): number {
    return this.activeOperations;
  }
}

/**
 * Memory monitoring utilities
 */
export class MemoryMonitor {
  private lastGC = Date.now();
  private readonly GC_INTERVAL = 60000; // 1 minute

  getStats(): MemoryStats {
    // In Workers, we estimate memory usage
    // Real implementation would use performance.memory if available
    const limit = 128 * 1024 * 1024; // 128MB typical Worker limit
    const used = this.estimateMemoryUsage();
    
    return {
      used,
      limit,
      percentage: used / limit,
      timestamp: Date.now()
    };
  }

  private estimateMemoryUsage(): number {
    // Rough estimation based on known allocations
    // In production, you'd track actual allocations
    return 50 * 1024 * 1024; // 50MB estimate
  }

  shouldTriggerGC(): boolean {
    return Date.now() - this.lastGC > this.GC_INTERVAL;
  }

  markGC(): void {
    this.lastGC = Date.now();
  }
}

/**
 * Connection pool for managing concurrent operations
 */
export class ConnectionPool {
  private activeConnections = 0;
  private queue: (() => void)[] = [];
  
  constructor(private maxConnections: number = 10) {}

  async acquire(): Promise<void> {
    if (this.activeConnections < this.maxConnections) {
      this.activeConnections++;
      return;
    }

    // Wait for a connection to be available
    return new Promise(resolve => {
      this.queue.push(resolve);
    });
  }

  release(): void {
    this.activeConnections--;
    
    if (this.queue.length > 0) {
      const next = this.queue.shift();
      if (next) {
        this.activeConnections++;
        next();
      }
    }
  }

  async withConnection<T>(operation: () => Promise<T>): Promise<T> {
    await this.acquire();
    try {
      return await operation();
    } finally {
      this.release();
    }
  }

  getStats() {
    return {
      active: this.activeConnections,
      queued: this.queue.length,
      available: this.maxConnections - this.activeConnections
    };
  }
}

/**
 * Performance optimizer service that combines all optimization strategies
 */
export class PerformanceOptimizer {
  private requestCoalescer = new RequestCoalescer();
  private kvCircuitBreaker: CircuitBreaker;
  private r2CircuitBreaker: CircuitBreaker;
  private parallelProcessor = new ParallelProcessor();
  private connectionPool = new ConnectionPool();
  private memoryMonitor = new MemoryMonitor();

  constructor(private env: Env) {
    // Initialize circuit breakers with sensible defaults
    this.kvCircuitBreaker = new CircuitBreaker({
      failureThreshold: 5,
      resetTimeout: 30000, // 30 seconds
      monitoringPeriod: 60000 // 1 minute
    });

    this.r2CircuitBreaker = new CircuitBreaker({
      failureThreshold: 3,
      resetTimeout: 60000, // 1 minute
      monitoringPeriod: 120000 // 2 minutes
    });
  }

  /**
   * Optimized KV get with coalescing and circuit breaker
   */
  async getFromKV(key: string): Promise<any> {
    return this.requestCoalescer.coalesce(`kv:${key}`, async () => {
      return this.kvCircuitBreaker.execute(async () => {
        return this.env.VIDEO_METADATA.get(key, 'json');
      });
    });
  }

  /**
   * Optimized batch KV operations
   */
  async batchGetFromKV(keys: string[]): Promise<any[]> {
    const tasks: Task<any>[] = keys.map(key => ({
      id: key,
      execute: () => this.getFromKV(key)
    }));

    return this.parallelProcessor.processParallel(tasks);
  }

  /**
   * Optimized R2 operations with connection pooling
   */
  async getFromR2(key: string): Promise<any> {
    return this.connectionPool.withConnection(async () => {
      return this.r2CircuitBreaker.execute(async () => {
        return this.env.VIDEO_BUCKET.head(key);
      });
    });
  }

  /**
   * Get performance statistics
   */
  getPerformanceStats() {
    return {
      requestCoalescing: {
        pendingRequests: this.requestCoalescer.getPendingCount()
      },
      circuitBreakers: {
        kv: this.kvCircuitBreaker.getStats(),
        r2: this.r2CircuitBreaker.getStats()
      },
      parallelProcessing: {
        activeOperations: this.parallelProcessor.getActiveOperations()
      },
      connectionPool: this.connectionPool.getStats(),
      memory: this.memoryMonitor.getStats()
    };
  }

  /**
   * Health check with performance metrics
   */
  async healthCheck(): Promise<{
    healthy: boolean;
    performance: any;
    recommendations: string[];
  }> {
    const stats = this.getPerformanceStats();
    const recommendations: string[] = [];
    let healthy = true;

    // Check circuit breakers
    if (stats.circuitBreakers.kv.state !== 'CLOSED') {
      healthy = false;
      recommendations.push('KV circuit breaker is open - check KV service health');
    }

    if (stats.circuitBreakers.r2.state !== 'CLOSED') {
      healthy = false;
      recommendations.push('R2 circuit breaker is open - check R2 service health');
    }

    // Check memory
    if (stats.memory.percentage > 0.8) {
      recommendations.push('Memory usage is high - consider optimizing allocations');
    }

    // Check connection pool
    if (stats.connectionPool.queued > 10) {
      recommendations.push('High connection queue - consider increasing pool size');
    }

    return {
      healthy,
      performance: stats,
      recommendations
    };
  }
}