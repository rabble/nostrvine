// ABOUTME: Deployment configuration for gradual feature rollout
// ABOUTME: Defines rollout stages and success criteria for video caching system

export interface RolloutStage {
  name: string;
  percentage: number;
  duration: string;
  criteria: SuccessCriteria;
  regions?: string[];
  userSegments?: string[];
}

export interface SuccessCriteria {
  minDuration: string;
  metrics: {
    loadTime: number; // milliseconds
    successRate: number; // 0-1
    cacheHitRate: number; // 0-1
    errorRate: number; // 0-1
    p95ResponseTime: number; // milliseconds
    minSampleSize: number;
  };
  alerts?: {
    errorRateThreshold: number;
    responseTimeThreshold: number;
    notificationChannels: string[];
  };
}

export interface FeatureRolloutConfig {
  featureName: string;
  description: string;
  stages: RolloutStage[];
  rollbackTriggers: RollbackTrigger[];
  monitoring: MonitoringConfig;
  abTests?: ABTestConfig[];
}

export interface RollbackTrigger {
  metric: string;
  threshold: number;
  duration: string;
  action: 'pause' | 'rollback' | 'alert';
}

export interface MonitoringConfig {
  dashboardUrl: string;
  metrics: string[];
  alertChannels: string[];
  checkInterval: string;
}

export interface ABTestConfig {
  name: string;
  variants: Array<{
    name: string;
    percentage: number;
    config: any;
  }>;
  metrics: string[];
  duration: string;
}

// Video Caching System Rollout Configuration
export const VIDEO_CACHING_ROLLOUT: FeatureRolloutConfig = {
  featureName: 'video_caching_system',
  description: 'New video caching system with instant playback and improved performance',
  
  stages: [
    {
      name: 'Canary',
      percentage: 5,
      duration: '24h',
      criteria: {
        minDuration: '24h',
        metrics: {
          loadTime: 500,
          successRate: 0.99,
          cacheHitRate: 0.90,
          errorRate: 0.01,
          p95ResponseTime: 200,
          minSampleSize: 1000,
        },
        alerts: {
          errorRateThreshold: 0.02,
          responseTimeThreshold: 300,
          notificationChannels: ['slack', 'pagerduty'],
        },
      },
      regions: ['us-east-1'],
      userSegments: ['beta_testers'],
    },
    {
      name: 'Early Adopters',
      percentage: 20,
      duration: '48h',
      criteria: {
        minDuration: '48h',
        metrics: {
          loadTime: 500,
          successRate: 0.99,
          cacheHitRate: 0.90,
          errorRate: 0.01,
          p95ResponseTime: 250,
          minSampleSize: 10000,
        },
      },
      regions: ['us-east-1', 'us-west-2'],
    },
    {
      name: 'Broader Rollout',
      percentage: 50,
      duration: '72h',
      criteria: {
        minDuration: '72h',
        metrics: {
          loadTime: 500,
          successRate: 0.99,
          cacheHitRate: 0.90,
          errorRate: 0.01,
          p95ResponseTime: 300,
          minSampleSize: 50000,
        },
      },
    },
    {
      name: 'General Availability',
      percentage: 100,
      duration: 'permanent',
      criteria: {
        minDuration: '7d',
        metrics: {
          loadTime: 500,
          successRate: 0.99,
          cacheHitRate: 0.90,
          errorRate: 0.01,
          p95ResponseTime: 350,
          minSampleSize: 100000,
        },
      },
    },
  ],
  
  rollbackTriggers: [
    {
      metric: 'errorRate',
      threshold: 0.05, // 5% error rate
      duration: '5m',
      action: 'rollback',
    },
    {
      metric: 'p95ResponseTime',
      threshold: 1000, // 1 second
      duration: '10m',
      action: 'pause',
    },
    {
      metric: 'successRate',
      threshold: 0.95, // Below 95% success
      duration: '15m',
      action: 'alert',
    },
    {
      metric: 'cacheHitRate',
      threshold: 0.70, // Below 70% cache hits
      duration: '30m',
      action: 'alert',
    },
  ],
  
  monitoring: {
    dashboardUrl: 'https://dash.cloudflare.com/nostrvine/analytics',
    metrics: [
      'requests_per_second',
      'response_time_p50',
      'response_time_p95',
      'response_time_p99',
      'cache_hit_rate',
      'error_rate',
      'bandwidth_usage',
      'unique_users',
    ],
    alertChannels: ['slack:#nostrvine-alerts', 'email:ops@nostrvine.com'],
    checkInterval: '1m',
  },
  
  abTests: [
    {
      name: 'cache_ttl_optimization',
      variants: [
        {
          name: 'control',
          percentage: 50,
          config: { cacheTTL: 300 }, // 5 minutes
        },
        {
          name: 'extended',
          percentage: 50,
          config: { cacheTTL: 600 }, // 10 minutes
        },
      ],
      metrics: ['cache_hit_rate', 'bandwidth_usage', 'response_time'],
      duration: '7d',
    },
    {
      name: 'prefetch_strategy',
      variants: [
        {
          name: 'conservative',
          percentage: 33,
          config: { prefetchCount: 3, prefetchQuality: '480p' },
        },
        {
          name: 'balanced',
          percentage: 34,
          config: { prefetchCount: 5, prefetchQuality: '480p' },
        },
        {
          name: 'aggressive',
          percentage: 33,
          config: { prefetchCount: 8, prefetchQuality: '720p' },
        },
      ],
      metrics: ['playback_start_time', 'bandwidth_usage', 'cache_efficiency'],
      duration: '14d',
    },
  ],
};

// Deployment scripts and automation
export const DEPLOYMENT_SCRIPTS = {
  // Script to check if we can proceed to next stage
  checkStageReadiness: async (
    stage: RolloutStage,
    currentMetrics: any
  ): Promise<{ ready: boolean; issues: string[] }> => {
    const issues: string[] = [];
    
    // Check minimum duration
    // This would check actual deployment time in production
    
    // Check success criteria
    const metrics = currentMetrics;
    const criteria = stage.criteria.metrics;
    
    if (metrics.loadTime > criteria.loadTime) {
      issues.push(`Load time ${metrics.loadTime}ms exceeds ${criteria.loadTime}ms`);
    }
    
    if (metrics.successRate < criteria.successRate) {
      issues.push(`Success rate ${metrics.successRate} below ${criteria.successRate}`);
    }
    
    if (metrics.cacheHitRate < criteria.cacheHitRate) {
      issues.push(`Cache hit rate ${metrics.cacheHitRate} below ${criteria.cacheHitRate}`);
    }
    
    if (metrics.errorRate > criteria.errorRate) {
      issues.push(`Error rate ${metrics.errorRate} exceeds ${criteria.errorRate}`);
    }
    
    if (metrics.sampleSize < criteria.minSampleSize) {
      issues.push(`Sample size ${metrics.sampleSize} below minimum ${criteria.minSampleSize}`);
    }
    
    return {
      ready: issues.length === 0,
      issues,
    };
  },
  
  // Script to advance to next stage
  advanceStage: async (
    currentStage: number,
    config: FeatureRolloutConfig
  ): Promise<void> => {
    if (currentStage >= config.stages.length - 1) {
      console.log('Already at final stage');
      return;
    }
    
    const nextStage = config.stages[currentStage + 1];
    console.log(`Advancing to stage: ${nextStage.name} (${nextStage.percentage}%)`);
    
    // Update feature flag configuration
    // This would call the feature flag API in production
  },
  
  // Script to rollback
  rollback: async (
    reason: string,
    config: FeatureRolloutConfig
  ): Promise<void> => {
    console.log(`Rolling back ${config.featureName}: ${reason}`);
    
    // Disable feature flag
    // Notify teams
    // Create incident report
  },
};

// Monitoring queries for Cloudflare Analytics
export const MONITORING_QUERIES = {
  // GraphQL query for video cache performance
  videoCachePerformance: `
    query VideoCachePerformance($start: String!, $end: String!) {
      viewer {
        zones(filter: { zoneTag: $zoneTag }) {
          httpRequests1hGroups(
            filter: {
              datetime_geq: $start
              datetime_lt: $end
              clientRequestPath_like: "/api/video/%"
            }
            orderBy: [datetime_ASC]
            limit: 10000
          ) {
            dimensions {
              datetime
              clientRequestPath
              cacheStatus
            }
            sum {
              requests
              bytes
              cachedBytes
            }
            avg {
              originResponseDurationMs
            }
            quantiles {
              originResponseDurationMsP50
              originResponseDurationMsP95
              originResponseDurationMsP99
            }
          }
        }
      }
    }
  `,
  
  // Query for error rates
  errorRates: `
    query ErrorRates($start: String!, $end: String!) {
      viewer {
        zones(filter: { zoneTag: $zoneTag }) {
          httpRequests1hGroups(
            filter: {
              datetime_geq: $start
              datetime_lt: $end
              clientRequestPath_like: "/api/%"
              edgeResponseStatus_geq: 400
            }
            orderBy: [datetime_ASC]
            limit: 10000
          ) {
            dimensions {
              datetime
              edgeResponseStatus
              clientRequestPath
            }
            sum {
              requests
            }
          }
        }
      }
    }
  `,
};

// Export CLI commands for deployment management
export const CLI_COMMANDS = {
  // Check current rollout status
  status: 'wrangler kv:key get --namespace-id=METADATA_CACHE "feature_flag:video_caching_system"',
  
  // Update rollout percentage
  updatePercentage: (percentage: number) => 
    `curl -X PUT https://api.nostrvine.com/api/feature-flags/video_caching_system \\
      -H "Authorization: Bearer $ADMIN_API_KEY" \\
      -H "Content-Type: application/json" \\
      -d '{"rolloutPercentage": ${percentage}}'`,
  
  // Check rollout health
  checkHealth: 'curl https://api.nostrvine.com/api/feature-flags/video_caching_system/health \\
    -H "Authorization: Bearer $ADMIN_API_KEY"',
  
  // Trigger rollback
  rollback: (reason: string) =>
    `curl -X POST https://api.nostrvine.com/api/feature-flags/video_caching_system/rollback \\
      -H "Authorization: Bearer $ADMIN_API_KEY" \\
      -H "Content-Type: application/json" \\
      -d '{"reason": "${reason}"}'`,
};