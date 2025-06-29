// ABOUTME: Type definitions for minimal analytics system
// ABOUTME: Focused on content metrics, no user tracking

export interface ViewData {
  count: number;
  lastUpdate: number; // timestamp
  hashtags?: string[]; // Hashtags associated with this video
  creatorPubkey?: string; // Creator's public key
  title?: string; // Video title for display
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
  hashtags?: string[]; // Video hashtags for trending calculation
  title?: string; // Video title
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
  ANALYTICS_DB?: D1Database; // Optional until we set it up
  ENVIRONMENT: string;
  TRENDING_UPDATE_INTERVAL: string;
  MIN_VIEWS_FOR_TRENDING: string;
}

// Time window analytics
export interface TimeWindowStats {
  eventId: string;
  views1h: number;
  views6h: number;
  views24h: number;
  views7d: number;
  views30d: number;
  velocityScore: number;
}

// Hashtag trending data
export interface HashtagTrending {
  hashtag: string;
  timeframe: '1h' | '6h' | '24h' | '7d' | '30d';
  videoCount: number;
  totalViews: number;
  topVideos: TrendingVideo[];
}