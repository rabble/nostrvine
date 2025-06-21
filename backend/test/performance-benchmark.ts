// ABOUTME: Performance benchmarking suite for NostrVine video API
// ABOUTME: Measures latency, throughput, and scalability metrics

import { performance } from 'perf_hooks';
import fetch from 'node-fetch';
import { Worker } from 'worker_threads';
import crypto from 'crypto';
import fs from 'fs/promises';
import path from 'path';

// Configuration
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:8787';
const TEST_API_KEY = process.env.TEST_API_KEY || 'test-key-123';
const BENCHMARK_DURATION = parseInt(process.env.BENCHMARK_DURATION || '30000'); // 30 seconds
const MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '50');

// Benchmark results interface
interface BenchmarkResult {
  testName: string;
  duration: number;
  totalRequests: number;
  successfulRequests: number;
  failedRequests: number;
  averageLatency: number;
  p50Latency: number;
  p95Latency: number;
  p99Latency: number;
  minLatency: number;
  maxLatency: number;
  requestsPerSecond: number;
  throughputMBps: number;
  errorRate: number;
  statusCodes: Record<number, number>;
}

interface LatencyBucket {
  timestamp: number;
  latency: number;
  statusCode: number;
  size: number;
}

class PerformanceBenchmark {
  private results: BenchmarkResult[] = [];
  private latencyBuckets: LatencyBucket[] = [];

  async runAllBenchmarks(): Promise<void> {
    console.log('🚀 Starting NostrVine Performance Benchmarks');
    console.log(`API URL: ${API_BASE_URL}`);
    console.log(`Duration: ${BENCHMARK_DURATION}ms`);
    console.log(`Max Concurrent: ${MAX_CONCURRENT}`);
    console.log('');

    // Run benchmarks sequentially to avoid interference
    await this.runBenchmark('Single Video Metadata', this.benchmarkSingleVideo.bind(this));
    await this.cooldown();
    
    await this.runBenchmark('Batch Video Lookup (10 videos)', this.benchmarkBatchSmall.bind(this));
    await this.cooldown();
    
    await this.runBenchmark('Batch Video Lookup (50 videos)', this.benchmarkBatchLarge.bind(this));
    await this.cooldown();
    
    await this.runBenchmark('Mixed Workload', this.benchmarkMixedWorkload.bind(this));
    await this.cooldown();
    
    await this.runBenchmark('Concurrent Connections', this.benchmarkConcurrentConnections.bind(this));
    await this.cooldown();
    
    await this.runBenchmark('Analytics Endpoint', this.benchmarkAnalytics.bind(this));
    
    // Generate report
    await this.generateReport();
  }

  private async runBenchmark(
    name: string,
    benchmarkFn: () => Promise<void>
  ): Promise<void> {
    console.log(`\n📊 Running benchmark: ${name}`);
    this.latencyBuckets = [];
    
    const startTime = performance.now();
    await benchmarkFn();
    const endTime = performance.now();
    
    const result = this.calculateResults(name, endTime - startTime);
    this.results.push(result);
    
    this.printResult(result);
  }

  private async benchmarkSingleVideo(): Promise<void> {
    const videoId = crypto.randomBytes(32).toString('hex');
    const endTime = Date.now() + BENCHMARK_DURATION;
    
    while (Date.now() < endTime) {
      await this.makeRequest(`/api/video/${videoId}`);
    }
  }

  private async benchmarkBatchSmall(): Promise<void> {
    const videoIds = Array.from({ length: 10 }, () => 
      crypto.randomBytes(32).toString('hex')
    );
    const endTime = Date.now() + BENCHMARK_DURATION;
    
    while (Date.now() < endTime) {
      await this.makeRequest('/api/videos/batch', {
        method: 'POST',
        body: JSON.stringify({ videoIds, quality: '720p' }),
      });
    }
  }

  private async benchmarkBatchLarge(): Promise<void> {
    const videoIds = Array.from({ length: 50 }, () => 
      crypto.randomBytes(32).toString('hex')
    );
    const endTime = Date.now() + BENCHMARK_DURATION;
    
    while (Date.now() < endTime) {
      await this.makeRequest('/api/videos/batch', {
        method: 'POST',
        body: JSON.stringify({ videoIds, quality: 'auto' }),
      });
    }
  }

  private async benchmarkMixedWorkload(): Promise<void> {
    const videoIds = Array.from({ length: 20 }, () => 
      crypto.randomBytes(32).toString('hex')
    );
    const endTime = Date.now() + BENCHMARK_DURATION;
    let requestCount = 0;
    
    while (Date.now() < endTime) {
      // Mix of single and batch requests
      if (requestCount % 3 === 0) {
        // Batch request
        await this.makeRequest('/api/videos/batch', {
          method: 'POST',
          body: JSON.stringify({
            videoIds: videoIds.slice(0, Math.floor(Math.random() * 10) + 1),
            quality: Math.random() > 0.5 ? '720p' : '480p',
          }),
        });
      } else {
        // Single request
        await this.makeRequest(`/api/video/${videoIds[requestCount % videoIds.length]}`);
      }
      requestCount++;
    }
  }

  private async benchmarkConcurrentConnections(): Promise<void> {
    const endTime = Date.now() + BENCHMARK_DURATION;
    const videoId = crypto.randomBytes(32).toString('hex');
    
    while (Date.now() < endTime) {
      const promises = [];
      
      // Launch concurrent requests
      for (let i = 0; i < MAX_CONCURRENT; i++) {
        promises.push(this.makeRequest(`/api/video/${videoId}`));
      }
      
      // Wait for all to complete
      await Promise.all(promises);
    }
  }

  private async benchmarkAnalytics(): Promise<void> {
    const endTime = Date.now() + BENCHMARK_DURATION;
    const endpoints = [
      '/api/analytics/popular?window=1h',
      '/api/analytics/popular?window=24h',
      '/api/analytics/dashboard',
    ];
    let requestCount = 0;
    
    while (Date.now() < endTime) {
      await this.makeRequest(endpoints[requestCount % endpoints.length]);
      requestCount++;
    }
  }

  private async makeRequest(
    path: string,
    options: any = {}
  ): Promise<void> {
    const startTime = performance.now();
    
    try {
      const response = await fetch(`${API_BASE_URL}${path}`, {
        ...options,
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'Content-Type': 'application/json',
          ...options.headers,
        },
      });
      
      const endTime = performance.now();
      const latency = endTime - startTime;
      
      // Read response body to measure size
      const body = await response.text();
      const size = new TextEncoder().encode(body).length;
      
      this.latencyBuckets.push({
        timestamp: Date.now(),
        latency,
        statusCode: response.status,
        size,
      });
    } catch (error) {
      const endTime = performance.now();
      const latency = endTime - startTime;
      
      this.latencyBuckets.push({
        timestamp: Date.now(),
        latency,
        statusCode: 0, // Network error
        size: 0,
      });
    }
  }

  private calculateResults(testName: string, duration: number): BenchmarkResult {
    const latencies = this.latencyBuckets.map(b => b.latency).sort((a, b) => a - b);
    const statusCodes: Record<number, number> = {};
    let totalSize = 0;
    
    this.latencyBuckets.forEach(bucket => {
      statusCodes[bucket.statusCode] = (statusCodes[bucket.statusCode] || 0) + 1;
      totalSize += bucket.size;
    });
    
    const successfulRequests = this.latencyBuckets.filter(b => 
      b.statusCode >= 200 && b.statusCode < 300
    ).length;
    
    const failedRequests = this.latencyBuckets.length - successfulRequests;
    
    return {
      testName,
      duration: duration / 1000, // Convert to seconds
      totalRequests: this.latencyBuckets.length,
      successfulRequests,
      failedRequests,
      averageLatency: latencies.reduce((a, b) => a + b, 0) / latencies.length,
      p50Latency: this.percentile(latencies, 50),
      p95Latency: this.percentile(latencies, 95),
      p99Latency: this.percentile(latencies, 99),
      minLatency: Math.min(...latencies),
      maxLatency: Math.max(...latencies),
      requestsPerSecond: this.latencyBuckets.length / (duration / 1000),
      throughputMBps: (totalSize / 1024 / 1024) / (duration / 1000),
      errorRate: failedRequests / this.latencyBuckets.length,
      statusCodes,
    };
  }

  private percentile(sortedArray: number[], percentile: number): number {
    const index = Math.ceil((percentile / 100) * sortedArray.length) - 1;
    return sortedArray[Math.max(0, index)];
  }

  private printResult(result: BenchmarkResult): void {
    console.log(`
  ✅ ${result.testName}
  ├─ Requests: ${result.totalRequests} total (${result.successfulRequests} successful)
  ├─ RPS: ${result.requestsPerSecond.toFixed(2)} req/s
  ├─ Throughput: ${result.throughputMBps.toFixed(2)} MB/s
  ├─ Latency:
  │  ├─ Average: ${result.averageLatency.toFixed(2)}ms
  │  ├─ P50: ${result.p50Latency.toFixed(2)}ms
  │  ├─ P95: ${result.p95Latency.toFixed(2)}ms
  │  ├─ P99: ${result.p99Latency.toFixed(2)}ms
  │  ├─ Min: ${result.minLatency.toFixed(2)}ms
  │  └─ Max: ${result.maxLatency.toFixed(2)}ms
  ├─ Error Rate: ${(result.errorRate * 100).toFixed(2)}%
  └─ Status Codes: ${JSON.stringify(result.statusCodes)}
    `);
  }

  private async cooldown(seconds: number = 5): Promise<void> {
    console.log(`⏸️  Cooling down for ${seconds} seconds...`);
    await new Promise(resolve => setTimeout(resolve, seconds * 1000));
  }

  private async generateReport(): Promise<void> {
    const reportPath = path.join(__dirname, `benchmark-report-${Date.now()}.json`);
    
    const report = {
      timestamp: new Date().toISOString(),
      configuration: {
        apiUrl: API_BASE_URL,
        duration: BENCHMARK_DURATION,
        maxConcurrent: MAX_CONCURRENT,
      },
      results: this.results,
      summary: {
        totalRequests: this.results.reduce((sum, r) => sum + r.totalRequests, 0),
        totalDuration: this.results.reduce((sum, r) => sum + r.duration, 0),
        averageRPS: this.results.reduce((sum, r) => sum + r.requestsPerSecond, 0) / this.results.length,
        averageLatency: this.results.reduce((sum, r) => sum + r.averageLatency, 0) / this.results.length,
        averageErrorRate: this.results.reduce((sum, r) => sum + r.errorRate, 0) / this.results.length,
      },
    };
    
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));
    
    console.log(`
=====================================
📈 BENCHMARK SUMMARY
=====================================
Total Requests: ${report.summary.totalRequests}
Total Duration: ${report.summary.totalDuration.toFixed(2)}s
Average RPS: ${report.summary.averageRPS.toFixed(2)} req/s
Average Latency: ${report.summary.averageLatency.toFixed(2)}ms
Average Error Rate: ${(report.summary.averageErrorRate * 100).toFixed(2)}%

Report saved to: ${reportPath}
    `);
  }
}

// Stress test runner for sustained load
class StressTest {
  async runStressTest(
    durationMinutes: number = 5,
    rampUpMinutes: number = 1
  ): Promise<void> {
    console.log(`
🔥 Starting Stress Test
Duration: ${durationMinutes} minutes
Ramp-up: ${rampUpMinutes} minutes
    `);
    
    const startTime = Date.now();
    const rampUpDuration = rampUpMinutes * 60 * 1000;
    const totalDuration = durationMinutes * 60 * 1000;
    const maxRPS = 100; // Target requests per second
    
    const metrics: any[] = [];
    
    while (Date.now() - startTime < totalDuration) {
      const elapsed = Date.now() - startTime;
      const currentRPS = elapsed < rampUpDuration
        ? (elapsed / rampUpDuration) * maxRPS
        : maxRPS;
      
      const startSecond = Date.now();
      const promises = [];
      
      // Generate load for this second
      for (let i = 0; i < currentRPS; i++) {
        promises.push(this.makeStressRequest());
      }
      
      const results = await Promise.allSettled(promises);
      const endSecond = Date.now();
      
      // Collect metrics
      const successful = results.filter(r => r.status === 'fulfilled').length;
      const failed = results.filter(r => r.status === 'rejected').length;
      
      metrics.push({
        timestamp: Date.now(),
        targetRPS: currentRPS,
        actualRPS: promises.length / ((endSecond - startSecond) / 1000),
        successful,
        failed,
        errorRate: failed / promises.length,
      });
      
      // Wait for next second
      const waitTime = 1000 - (endSecond - startSecond);
      if (waitTime > 0) {
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
      
      // Print progress every 10 seconds
      if (metrics.length % 10 === 0) {
        const recent = metrics.slice(-10);
        const avgRPS = recent.reduce((sum, m) => sum + m.actualRPS, 0) / recent.length;
        const avgError = recent.reduce((sum, m) => sum + m.errorRate, 0) / recent.length;
        
        console.log(`Progress: ${(elapsed / 1000).toFixed(0)}s | RPS: ${avgRPS.toFixed(1)} | Error: ${(avgError * 100).toFixed(1)}%`);
      }
    }
    
    this.printStressTestSummary(metrics);
  }

  private async makeStressRequest(): Promise<void> {
    const endpoints = [
      `/api/video/${crypto.randomBytes(32).toString('hex')}`,
      '/api/videos/batch',
      '/api/analytics/popular',
    ];
    
    const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
    
    if (endpoint === '/api/videos/batch') {
      const videoIds = Array.from({ length: Math.floor(Math.random() * 10) + 1 }, () =>
        crypto.randomBytes(32).toString('hex')
      );
      
      await fetch(`${API_BASE_URL}${endpoint}`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ videoIds }),
      });
    } else {
      await fetch(`${API_BASE_URL}${endpoint}`, {
        headers: {
          'Authorization': `Bearer ${TEST_API_KEY}`,
        },
      });
    }
  }

  private printStressTestSummary(metrics: any[]): void {
    const totalRequests = metrics.reduce((sum, m) => sum + m.successful + m.failed, 0);
    const totalSuccessful = metrics.reduce((sum, m) => sum + m.successful, 0);
    const avgRPS = metrics.reduce((sum, m) => sum + m.actualRPS, 0) / metrics.length;
    const avgErrorRate = metrics.reduce((sum, m) => sum + m.errorRate, 0) / metrics.length;
    
    console.log(`
=====================================
🔥 STRESS TEST SUMMARY
=====================================
Total Requests: ${totalRequests}
Successful: ${totalSuccessful}
Average RPS: ${avgRPS.toFixed(2)}
Average Error Rate: ${(avgErrorRate * 100).toFixed(2)}%
Duration: ${metrics.length} seconds
    `);
  }
}

// Main execution
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.includes('--stress')) {
    const stressTest = new StressTest();
    stressTest.runStressTest().catch(console.error);
  } else {
    const benchmark = new PerformanceBenchmark();
    benchmark.runAllBenchmarks().catch(console.error);
  }
}