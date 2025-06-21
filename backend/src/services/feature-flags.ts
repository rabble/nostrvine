// ABOUTME: Feature flag service for gradual rollout and A/B testing
// ABOUTME: Enables percentage-based user segmentation and controlled feature deployment

import crypto from 'crypto';

export interface FeatureFlag {
  name: string;
  enabled: boolean;
  rolloutPercentage: number;
  variants?: FeatureFlagVariant[];
  metadata?: Record<string, any>;
  createdAt: string;
  updatedAt: string;
}

export interface FeatureFlagVariant {
  name: string;
  percentage: number;
  metadata?: Record<string, any>;
}

export interface FeatureFlagDecision {
  enabled: boolean;
  variant?: string;
  reason: string;
  metadata?: Record<string, any>;
}

export interface RolloutMetrics {
  flagName: string;
  enabled: number;
  disabled: number;
  variants: Record<string, number>;
  errorRate: number;
  performanceMetrics?: {
    averageResponseTime: number;
    p95ResponseTime: number;
    cacheHitRate: number;
    successRate: number;
  };
}

// Default feature flags
const DEFAULT_FLAGS: Record<string, Partial<FeatureFlag>> = {
  'video_caching_system': {
    enabled: true,
    rolloutPercentage: 5, // Start with 5% rollout
    metadata: {
      description: 'New video caching system with instant playback',
      successCriteria: {
        loadTime: 500, // ms
        successRate: 0.99,
        cacheHitRate: 0.90,
        errorRate: 0.01,
      },
    },
  },
  'optimized_batch_api': {
    enabled: true,
    rolloutPercentage: 20,
    metadata: {
      description: 'Optimized batch video lookup with parallel processing',
    },
  },
  'prefetch_manager': {
    enabled: true,
    rolloutPercentage: 10,
    variants: [
      { name: 'aggressive', percentage: 30 },
      { name: 'balanced', percentage: 50 },
      { name: 'conservative', percentage: 20 },
    ],
  },
  'analytics_v2': {
    enabled: false,
    rolloutPercentage: 0,
    metadata: {
      description: 'Enhanced analytics with real-time dashboards',
    },
  },
};

export class FeatureFlagService {
  private env: Env;
  private ctx?: ExecutionContext;
  private flagCache: Map<string, FeatureFlag> = new Map();
  private readonly CACHE_TTL = 300; // 5 minutes
  private lastCacheUpdate = 0;

  constructor(env: Env, ctx?: ExecutionContext) {
    this.env = env;
    this.ctx = ctx;
  }

  /**
   * Check if a feature is enabled for a specific user
   */
  async isEnabled(
    flagName: string,
    userId?: string,
    attributes?: Record<string, any>
  ): Promise<FeatureFlagDecision> {
    try {
      const flag = await this.getFlag(flagName);
      
      if (!flag) {
        return {
          enabled: false,
          reason: 'Flag not found',
        };
      }

      // Check if flag is globally disabled
      if (!flag.enabled) {
        return {
          enabled: false,
          reason: 'Flag globally disabled',
        };
      }

      // Check rollout percentage
      const userHash = this.getUserHash(flagName, userId || 'anonymous');
      const rolloutBucket = this.getBucket(userHash);
      
      if (rolloutBucket > flag.rolloutPercentage) {
        return {
          enabled: false,
          reason: `User not in rollout (bucket: ${rolloutBucket}, rollout: ${flag.rolloutPercentage}%)`,
        };
      }

      // Check for variants
      let variant: string | undefined;
      if (flag.variants && flag.variants.length > 0) {
        variant = this.selectVariant(flag.variants, userHash);
      }

      // Track decision
      if (this.ctx) {
        this.ctx.waitUntil(
          this.trackDecision(flagName, true, variant, userId, attributes)
        );
      }

      return {
        enabled: true,
        variant,
        reason: `User in rollout (bucket: ${rolloutBucket})`,
        metadata: flag.metadata,
      };
    } catch (error) {
      console.error(`Error checking feature flag ${flagName}:`, error);
      
      // Fail open or closed based on flag configuration
      const defaultEnabled = DEFAULT_FLAGS[flagName]?.enabled ?? false;
      return {
        enabled: defaultEnabled,
        reason: 'Error checking flag, using default',
      };
    }
  }

  /**
   * Get all feature flags
   */
  async getAllFlags(): Promise<FeatureFlag[]> {
    const flags: FeatureFlag[] = [];
    
    // Load from KV if available
    const storedFlags = await this.loadFlagsFromKV();
    
    // Merge with defaults
    for (const [name, defaultFlag] of Object.entries(DEFAULT_FLAGS)) {
      const storedFlag = storedFlags.find(f => f.name === name);
      
      if (storedFlag) {
        flags.push(storedFlag);
      } else {
        flags.push({
          name,
          enabled: defaultFlag.enabled ?? false,
          rolloutPercentage: defaultFlag.rolloutPercentage ?? 0,
          variants: defaultFlag.variants,
          metadata: defaultFlag.metadata,
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        });
      }
    }
    
    return flags;
  }

  /**
   * Update a feature flag
   */
  async updateFlag(
    flagName: string,
    updates: Partial<FeatureFlag>
  ): Promise<FeatureFlag> {
    const existingFlag = await this.getFlag(flagName);
    
    const updatedFlag: FeatureFlag = {
      name: flagName,
      enabled: updates.enabled ?? existingFlag?.enabled ?? false,
      rolloutPercentage: updates.rolloutPercentage ?? existingFlag?.rolloutPercentage ?? 0,
      variants: updates.variants ?? existingFlag?.variants,
      metadata: updates.metadata ?? existingFlag?.metadata,
      createdAt: existingFlag?.createdAt ?? new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    // Save to KV
    await this.env.METADATA_CACHE.put(
      `feature_flag:${flagName}`,
      JSON.stringify(updatedFlag),
      {
        expirationTtl: 86400 * 30, // 30 days
      }
    );

    // Update cache
    this.flagCache.set(flagName, updatedFlag);

    // Track update
    if (this.ctx) {
      this.ctx.waitUntil(
        this.trackFlagUpdate(flagName, updatedFlag)
      );
    }

    return updatedFlag;
  }

  /**
   * Get rollout metrics for a feature flag
   */
  async getRolloutMetrics(flagName: string): Promise<RolloutMetrics> {
    const metricsKey = `feature_flag_metrics:${flagName}:${this.getCurrentHour()}`;
    const storedMetrics = await this.env.METADATA_CACHE.get(metricsKey);
    
    if (storedMetrics) {
      return JSON.parse(storedMetrics);
    }

    // Return empty metrics if none found
    return {
      flagName,
      enabled: 0,
      disabled: 0,
      variants: {},
      errorRate: 0,
    };
  }

  /**
   * Enable gradual rollout for a flag
   */
  async gradualRollout(
    flagName: string,
    targetPercentage: number,
    incrementPercentage: number = 5,
    intervalMinutes: number = 30
  ): Promise<void> {
    const flag = await this.getFlag(flagName);
    
    if (!flag) {
      throw new Error(`Feature flag ${flagName} not found`);
    }

    // Schedule rollout increments
    const increments = Math.ceil(
      (targetPercentage - flag.rolloutPercentage) / incrementPercentage
    );

    for (let i = 0; i < increments; i++) {
      const newPercentage = Math.min(
        flag.rolloutPercentage + (incrementPercentage * (i + 1)),
        targetPercentage
      );

      // Schedule update using Durable Objects or external scheduler
      // For now, we'll just log the plan
      console.log(`Rollout plan for ${flagName}: ${newPercentage}% at ${new Date(
        Date.now() + (intervalMinutes * 60 * 1000 * (i + 1))
      ).toISOString()}`);
    }
  }

  /**
   * Check if rollout should be paused based on metrics
   */
  async checkRolloutHealth(flagName: string): Promise<{
    healthy: boolean;
    metrics: RolloutMetrics;
    issues: string[];
  }> {
    const metrics = await this.getRolloutMetrics(flagName);
    const flag = await this.getFlag(flagName);
    const issues: string[] = [];

    if (!flag || !flag.metadata?.successCriteria) {
      return { healthy: true, metrics, issues };
    }

    const criteria = flag.metadata.successCriteria;

    // Check performance metrics
    if (metrics.performanceMetrics) {
      const perf = metrics.performanceMetrics;
      
      if (criteria.loadTime && perf.averageResponseTime > criteria.loadTime) {
        issues.push(`Average response time (${perf.averageResponseTime}ms) exceeds threshold (${criteria.loadTime}ms)`);
      }

      if (criteria.successRate && perf.successRate < criteria.successRate) {
        issues.push(`Success rate (${perf.successRate}) below threshold (${criteria.successRate})`);
      }

      if (criteria.cacheHitRate && perf.cacheHitRate < criteria.cacheHitRate) {
        issues.push(`Cache hit rate (${perf.cacheHitRate}) below threshold (${criteria.cacheHitRate})`);
      }
    }

    // Check error rate
    if (criteria.errorRate && metrics.errorRate > criteria.errorRate) {
      issues.push(`Error rate (${metrics.errorRate}) exceeds threshold (${criteria.errorRate})`);
    }

    return {
      healthy: issues.length === 0,
      metrics,
      issues,
    };
  }

  /**
   * Rollback a feature flag
   */
  async rollback(flagName: string, reason: string): Promise<FeatureFlag> {
    console.warn(`Rolling back feature flag ${flagName}: ${reason}`);
    
    const updatedFlag = await this.updateFlag(flagName, {
      enabled: false,
      rolloutPercentage: 0,
      metadata: {
        ...(await this.getFlag(flagName))?.metadata,
        rollbackReason: reason,
        rollbackTime: new Date().toISOString(),
      },
    });

    // Track rollback event
    if (this.ctx) {
      this.ctx.waitUntil(
        this.trackRollback(flagName, reason)
      );
    }

    return updatedFlag;
  }

  // Private helper methods

  private async getFlag(flagName: string): Promise<FeatureFlag | null> {
    // Check cache first
    if (this.flagCache.has(flagName) && 
        Date.now() - this.lastCacheUpdate < this.CACHE_TTL * 1000) {
      return this.flagCache.get(flagName)!;
    }

    // Load from KV
    const storedFlag = await this.env.METADATA_CACHE.get(`feature_flag:${flagName}`);
    
    if (storedFlag) {
      const flag = JSON.parse(storedFlag) as FeatureFlag;
      this.flagCache.set(flagName, flag);
      return flag;
    }

    // Use default if available
    const defaultFlag = DEFAULT_FLAGS[flagName];
    if (defaultFlag) {
      const flag: FeatureFlag = {
        name: flagName,
        enabled: defaultFlag.enabled ?? false,
        rolloutPercentage: defaultFlag.rolloutPercentage ?? 0,
        variants: defaultFlag.variants,
        metadata: defaultFlag.metadata,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      };
      this.flagCache.set(flagName, flag);
      return flag;
    }

    return null;
  }

  private async loadFlagsFromKV(): Promise<FeatureFlag[]> {
    const flags: FeatureFlag[] = [];
    
    // List all feature flags in KV
    const list = await this.env.METADATA_CACHE.list({
      prefix: 'feature_flag:',
      limit: 100,
    });

    for (const key of list.keys) {
      const flagData = await this.env.METADATA_CACHE.get(key.name);
      if (flagData) {
        flags.push(JSON.parse(flagData));
      }
    }

    return flags;
  }

  private getUserHash(flagName: string, userId: string): string {
    const data = `${flagName}:${userId}`;
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  private getBucket(hash: string): number {
    // Convert first 8 chars of hash to number and map to 0-100
    const num = parseInt(hash.substring(0, 8), 16);
    return (num % 100) + 1;
  }

  private selectVariant(variants: FeatureFlagVariant[], userHash: string): string {
    const bucket = this.getBucket(userHash);
    let cumulativePercentage = 0;

    for (const variant of variants) {
      cumulativePercentage += variant.percentage;
      if (bucket <= cumulativePercentage) {
        return variant.name;
      }
    }

    // Default to last variant if percentages don't add up to 100
    return variants[variants.length - 1].name;
  }

  private async trackDecision(
    flagName: string,
    enabled: boolean,
    variant: string | undefined,
    userId?: string,
    attributes?: Record<string, any>
  ): Promise<void> {
    const hourlyKey = `feature_flag_metrics:${flagName}:${this.getCurrentHour()}`;
    
    try {
      // Get existing metrics
      const existing = await this.env.METADATA_CACHE.get(hourlyKey);
      const metrics: RolloutMetrics = existing ? JSON.parse(existing) : {
        flagName,
        enabled: 0,
        disabled: 0,
        variants: {},
        errorRate: 0,
      };

      // Update counts
      if (enabled) {
        metrics.enabled++;
        if (variant) {
          metrics.variants[variant] = (metrics.variants[variant] || 0) + 1;
        }
      } else {
        metrics.disabled++;
      }

      // Save updated metrics
      await this.env.METADATA_CACHE.put(
        hourlyKey,
        JSON.stringify(metrics),
        {
          expirationTtl: 86400 * 7, // Keep for 7 days
        }
      );
    } catch (error) {
      console.error('Failed to track feature flag decision:', error);
    }
  }

  private async trackFlagUpdate(flagName: string, flag: FeatureFlag): Promise<void> {
    const eventKey = `feature_flag_event:${flagName}:${Date.now()}`;
    
    await this.env.METADATA_CACHE.put(
      eventKey,
      JSON.stringify({
        type: 'update',
        flagName,
        flag,
        timestamp: new Date().toISOString(),
      }),
      {
        expirationTtl: 86400 * 30, // Keep for 30 days
      }
    );
  }

  private async trackRollback(flagName: string, reason: string): Promise<void> {
    const eventKey = `feature_flag_event:${flagName}:${Date.now()}`;
    
    await this.env.METADATA_CACHE.put(
      eventKey,
      JSON.stringify({
        type: 'rollback',
        flagName,
        reason,
        timestamp: new Date().toISOString(),
      }),
      {
        expirationTtl: 86400 * 90, // Keep rollback events for 90 days
      }
    );
  }

  private getCurrentHour(): string {
    const now = new Date();
    return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}-${String(now.getUTCDate()).padStart(2, '0')}-${String(now.getUTCHours()).padStart(2, '0')}`;
  }
}