-- ABOUTME: D1 database schema for OpenVine analytics engine
-- ABOUTME: Supports trending by hashtag, time windows, and creator analytics

-- Core video analytics table
CREATE TABLE IF NOT EXISTS video_analytics (
  event_id TEXT PRIMARY KEY,
  creator_pubkey TEXT NOT NULL,
  title TEXT,
  total_views INTEGER DEFAULT 0,
  views_1h INTEGER DEFAULT 0,
  views_6h INTEGER DEFAULT 0,
  views_24h INTEGER DEFAULT 0,
  views_7d INTEGER DEFAULT 0,
  views_30d INTEGER DEFAULT 0,
  velocity_score REAL DEFAULT 0.0,
  first_seen_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_view_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Hashtag associations for videos
CREATE TABLE IF NOT EXISTS video_hashtags (
  event_id TEXT NOT NULL,
  hashtag TEXT NOT NULL,
  position INTEGER DEFAULT 0, -- Order in which hashtag appears
  PRIMARY KEY (event_id, hashtag),
  FOREIGN KEY (event_id) REFERENCES video_analytics(event_id)
);

-- Hashtag trending data by time window
CREATE TABLE IF NOT EXISTS hashtag_trends (
  hashtag TEXT NOT NULL,
  timeframe TEXT NOT NULL, -- '1h', '6h', '24h', '7d', '30d'
  total_videos INTEGER DEFAULT 0,
  total_views INTEGER DEFAULT 0,
  trending_score REAL DEFAULT 0.0,
  top_videos JSON, -- Array of top video IDs
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (hashtag, timeframe)
);

-- Creator analytics
CREATE TABLE IF NOT EXISTS creator_analytics (
  pubkey TEXT PRIMARY KEY,
  display_name TEXT,
  total_videos INTEGER DEFAULT 0,
  total_views INTEGER DEFAULT 0,
  views_1h INTEGER DEFAULT 0,
  views_24h INTEGER DEFAULT 0,
  views_7d INTEGER DEFAULT 0,
  avg_views_per_video REAL DEFAULT 0.0,
  trending_score REAL DEFAULT 0.0,
  first_video_at TIMESTAMP,
  last_video_at TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Hourly view snapshots for time-series analysis
CREATE TABLE IF NOT EXISTS view_snapshots (
  event_id TEXT NOT NULL,
  hour_bucket TEXT NOT NULL, -- 'YYYY-MM-DD-HH'
  view_count INTEGER DEFAULT 0,
  PRIMARY KEY (event_id, hour_bucket),
  FOREIGN KEY (event_id) REFERENCES video_analytics(event_id)
);

-- Global trending cache
CREATE TABLE IF NOT EXISTS global_trending (
  timeframe TEXT PRIMARY KEY, -- '1h', '6h', '24h', '7d', '30d'
  video_ids JSON NOT NULL, -- Array of trending video IDs in order
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_video_analytics_creator ON video_analytics(creator_pubkey);
CREATE INDEX IF NOT EXISTS idx_video_analytics_velocity ON video_analytics(velocity_score DESC);
CREATE INDEX IF NOT EXISTS idx_video_analytics_views_24h ON video_analytics(views_24h DESC);
CREATE INDEX IF NOT EXISTS idx_video_analytics_updated ON video_analytics(updated_at);
CREATE INDEX IF NOT EXISTS idx_video_hashtags_hashtag ON video_hashtags(hashtag);
CREATE INDEX IF NOT EXISTS idx_view_snapshots_hour ON view_snapshots(hour_bucket);
CREATE INDEX IF NOT EXISTS idx_creator_analytics_trending ON creator_analytics(trending_score DESC);