// ABOUTME: Type definitions for minimal analytics system
// ABOUTME: Focused on content metrics, no user tracking

export interface ViewData {
  count: number;
  lastUpdate: number; // timestamp
  // Future: could add hourly buckets for trend calculation
}

export interface TrendingVideo {
  eventId: string;
  views: number;
  score: number; // calculated trending score
  title?: string; // optional metadata
  hashtags?: string[]; // optional for future hashtag trending
}

export interface TrendingData {
  videos: TrendingVideo[];
  updatedAt: number;
  // Future: could add hashtags, categories, etc.
}

export interface ViewRequest {
  eventId: string;
  source?: 'web' | 'mobile' | 'api';
  creatorPubkey?: string; // Optional: track creator metrics
  // Future: could add optional userId for opt-in personalization
}

export interface CreatorData {
  totalViews: number;
  videoCount: number;
  lastUpdate: number;
  // Future: could add follower count, engagement metrics
}

export interface TrendingCreator {
  pubkey: string;
  displayName?: string;
  totalViews: number;
  videoCount: number;
  score: number; // calculated trending score
  avgViewsPerVideo: number;
}

export interface AnalyticsEnv {
  ANALYTICS_KV: KVNamespace;
  ENVIRONMENT: string;
  TRENDING_UPDATE_INTERVAL: string;
  MIN_VIEWS_FOR_TRENDING: string;
}