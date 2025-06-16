// ABOUTME: Comprehensive benchmark comparing all frame capture approaches
// ABOUTME: Generates technical recommendations for optimal implementation

import 'dart:math';
import 'video_extraction/video_extraction_prototype.dart';
import 'image_stream/image_stream_prototype.dart';
import 'hybrid/hybrid_prototype.dart';

class FrameCaptureComparison {
  
  /// Run comprehensive benchmarks on all three approaches
  static Future<ComparisonResult> runComparison() async {
    print('🔬 Starting Frame Capture Approach Analysis...\n');
    
    // Test parameters for 6-second vine at 5 FPS
    const testDuration = Duration(seconds: 6);
    const targetFPS = 5.0;
    const targetFrameCount = 30;
    
    // Benchmark 1: Video Extraction Approach
    print('📹 Testing Video Extraction Approach...');
    final videoResult = await VideoExtractionBenchmark.runBenchmark();
    print('✅ Video approach completed: ${videoResult.frameCount} frames\n');
    
    // Benchmark 2: Image Stream Approach  
    print('📸 Testing Image Stream Approach...');
    final streamResult = await ImageStreamBenchmark.runBenchmark();
    print('✅ Stream approach completed: ${streamResult.frameCount} frames\n');
    
    // Benchmark 3: Hybrid Approach
    print('🔀 Testing Hybrid Approach...');
    final hybridResult = await HybridBenchmark.runBenchmark();
    print('✅ Hybrid approach completed: ${hybridResult.frameCount} frames\n');
    
    // Performance Analysis
    final analysis = _analyzeResults(videoResult, streamResult, hybridResult);
    
    return ComparisonResult(
      videoResult: videoResult,
      streamResult: streamResult,
      hybridResult: hybridResult,
      analysis: analysis,
      recommendation: _generateRecommendation(analysis),
    );
  }
  
  static PerformanceAnalysis _analyzeResults(
    VideoExtractionResult video,
    ImageStreamResult stream, 
    HybridResult hybrid,
  ) {
    // Scoring criteria (0-100 scale)
    final videoScore = _calculateScore(
      speed: _speedScore(video.totalTimeSeconds),
      reliability: _reliabilityScore(video.frameCount, 30),
      resourceUsage: _resourceScore(video.videoFileSize),
      complexity: 60, // Medium complexity
    );
    
    final streamScore = _calculateScore(
      speed: _speedScore(stream.captureTimeSeconds),
      reliability: _reliabilityScore(stream.frameCount, 30),
      resourceUsage: _resourceScore(stream.framesDataSize),
      complexity: 80, // Higher complexity (real-time processing)
    );
    
    final hybridScore = _calculateScore(
      speed: _speedScore(hybrid.totalTimeSeconds),
      reliability: _reliabilityScore(hybrid.frameCount, 30) * hybrid.reliabilityScore,
      resourceUsage: _resourceScore(hybrid.videoFileSize + hybrid.framesDataSize),
      complexity: 40, // Lower complexity (handles both scenarios)
    );
    
    return PerformanceAnalysis(
      videoScore: videoScore,
      streamScore: streamScore,
      hybridScore: hybridScore,
      speedComparison: {
        'Video': video.totalTimeSeconds,
        'Stream': stream.captureTimeSeconds,
        'Hybrid': hybrid.totalTimeSeconds,
      },
      reliabilityComparison: {
        'Video': video.frameCount / 30.0,
        'Stream': stream.frameCount / 30.0, 
        'Hybrid': hybrid.reliabilityScore,
      },
      resourceComparison: {
        'Video': video.videoFileSize / 1024.0,
        'Stream': stream.framesDataSize / 1024.0,
        'Hybrid': (hybrid.videoFileSize + hybrid.framesDataSize) / 1024.0,
      },
    );
  }
  
  static double _calculateScore({
    required double speed,
    required double reliability, 
    required double resourceUsage,
    required double complexity,
  }) {
    // Weighted scoring: reliability 40%, speed 30%, resources 20%, complexity 10%
    return (reliability * 0.4) + (speed * 0.3) + (resourceUsage * 0.2) + (complexity * 0.1);
  }
  
  static double _speedScore(double timeSeconds) {
    // Faster is better: 0-6s = 100, 6-12s = 50, 12s+ = 0
    return max(0, 100 - (timeSeconds * 100 / 6));
  }
  
  static double _reliabilityScore(int actualFrames, int targetFrames) {
    final ratio = actualFrames / targetFrames;
    return min(100, ratio * 100);
  }
  
  static double _resourceScore(int bytesUsed) {
    // Lower usage is better: 0-1MB = 100, 1-5MB = 50, 5MB+ = 0
    final mbUsed = bytesUsed / (1024 * 1024);
    return max(0, 100 - (mbUsed * 20));
  }
  
  static TechnicalRecommendation _generateRecommendation(PerformanceAnalysis analysis) {
    // Determine winner based on overall scores
    final scores = {
      'Video Extraction': analysis.videoScore,
      'Image Stream': analysis.streamScore,
      'Hybrid': analysis.hybridScore,
    };
    
    final winner = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    
    String rationale;
    String implementation;
    List<String> tradeoffs;
    
    switch (winner.key) {
      case 'Video Extraction':
        rationale = 'Video extraction provides good reliability with moderate resource usage. Best for apps where processing delay is acceptable.';
        implementation = 'Use camera.startVideoRecording() then extract frames post-recording using video processing libraries.';
        tradeoffs = [
          '+ Simple implementation',
          '+ Reliable frame capture',
          '+ Lower real-time CPU usage',
          '- Higher storage requirements',
          '- Processing delay after recording',
        ];
        break;
        
      case 'Image Stream':
        rationale = 'Real-time streaming provides immediate frame access with lower storage needs. Best for apps requiring instant feedback.';
        implementation = 'Use camera.startImageStream() with frame rate limiting and immediate processing pipeline.';
        tradeoffs = [
          '+ Immediate frame availability',
          '+ Lower storage usage',
          '+ Real-time processing capability',
          '- Higher CPU usage during recording',
          '- Potential frame drops under load',
        ];
        break;
        
      case 'Hybrid':
        rationale = 'Hybrid approach provides best reliability by combining both methods with intelligent fallback. Optimal for production apps.';
        implementation = 'Simultaneously run video recording and image streaming, use real-time frames when available, fallback to video extraction.';
        tradeoffs = [
          '+ Maximum reliability',
          '+ Adaptive to device performance',
          '+ Best user experience',
          '- Higher complexity',
          '- Increased resource usage',
        ];
        break;
        
      default:
        rationale = 'Analysis inconclusive. Manual review recommended.';
        implementation = 'Compare approaches manually based on specific requirements.';
        tradeoffs = ['Review individual benchmark results'];
    }
    
    return TechnicalRecommendation(
      recommendedApproach: winner.key,
      confidence: winner.value,
      rationale: rationale,
      implementation: implementation,
      tradeoffs: tradeoffs,
      nextSteps: [
        'Implement ${winner.key} approach in main camera integration',
        'Add performance monitoring for production validation',
        'Create unit tests for chosen implementation',
        'Document implementation decisions in technical docs',
      ],
    );
  }
}

class ComparisonResult {
  final VideoExtractionResult videoResult;
  final ImageStreamResult streamResult;
  final HybridResult hybridResult;
  final PerformanceAnalysis analysis;
  final TechnicalRecommendation recommendation;
  
  ComparisonResult({
    required this.videoResult,
    required this.streamResult,
    required this.hybridResult,
    required this.analysis,
    required this.recommendation,
  });
  
  @override
  String toString() {
    return '''
=== FRAME CAPTURE APPROACH ANALYSIS ===

📊 PERFORMANCE RESULTS:
${videoResult.toString()}
---
${streamResult.toString()}
---
${hybridResult.toString()}

📈 COMPARATIVE ANALYSIS:
Overall Scores:
- Video Extraction: ${analysis.videoScore.toStringAsFixed(1)}/100
- Image Stream: ${analysis.streamScore.toStringAsFixed(1)}/100  
- Hybrid: ${analysis.hybridScore.toStringAsFixed(1)}/100

Speed Comparison:
${analysis.speedComparison.entries.map((e) => '- ${e.key}: ${e.value.toStringAsFixed(2)}s').join('\n')}

Reliability Comparison:
${analysis.reliabilityComparison.entries.map((e) => '- ${e.key}: ${(e.value * 100).toStringAsFixed(1)}%').join('\n')}

Resource Usage Comparison:
${analysis.resourceComparison.entries.map((e) => '- ${e.key}: ${e.value.toStringAsFixed(1)} KB').join('\n')}

🎯 TECHNICAL RECOMMENDATION:
Approach: ${recommendation.recommendedApproach}
Confidence: ${recommendation.confidence.toStringAsFixed(1)}/100

Rationale: ${recommendation.rationale}

Implementation: ${recommendation.implementation}

Trade-offs:
${recommendation.tradeoffs.map((t) => '  $t').join('\n')}

Next Steps:
${recommendation.nextSteps.map((s) => '  • $s').join('\n')}

=== ANALYSIS COMPLETE ===
''';
  }
}

class PerformanceAnalysis {
  final double videoScore;
  final double streamScore;
  final double hybridScore;
  final Map<String, double> speedComparison;
  final Map<String, double> reliabilityComparison;
  final Map<String, double> resourceComparison;
  
  PerformanceAnalysis({
    required this.videoScore,
    required this.streamScore,
    required this.hybridScore,
    required this.speedComparison,
    required this.reliabilityComparison,
    required this.resourceComparison,
  });
}

class TechnicalRecommendation {
  final String recommendedApproach;
  final double confidence;
  final String rationale;
  final String implementation;
  final List<String> tradeoffs;
  final List<String> nextSteps;
  
  TechnicalRecommendation({
    required this.recommendedApproach,
    required this.confidence,
    required this.rationale,
    required this.implementation,
    required this.tradeoffs,
    required this.nextSteps,
  });
}