#!/usr/bin/env node

// ABOUTME: Script to check video API analytics from the command line
// ABOUTME: Useful for monitoring and debugging analytics data

const API_URL = process.env.API_URL || 'http://localhost:8787';
const AUTH_TOKEN = process.env.AUTH_TOKEN || 'test-token';

async function fetchAnalytics(hours = 24) {
  try {
    const response = await fetch(`${API_URL}/api/analytics?hours=${hours}`, {
      headers: {
        'Authorization': `Bearer ${AUTH_TOKEN}`
      }
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Failed to fetch analytics:', error);
    process.exit(1);
  }
}

function formatMetrics(summary) {
  console.log('\n📊 VIDEO API ANALYTICS SUMMARY\n');
  console.log('=' .repeat(60));

  let totalVideoRequests = 0;
  let totalBatchRequests = 0;
  let totalCacheHits = 0;
  let totalVideosFound = 0;
  let totalVideosMissing = 0;

  summary.forEach(hourData => {
    const vm = hourData.videoMetadata || {};
    const bv = hourData.batchVideo || {};
    
    totalVideoRequests += vm.totalRequests || 0;
    totalBatchRequests += bv.totalRequests || 0;
    totalCacheHits += vm.cacheHits || 0;
    totalVideosFound += bv.totalVideosFound || 0;
    totalVideosMissing += bv.totalVideosMissing || 0;
  });

  console.log('📹 Video Metadata API:');
  console.log(`   Total Requests: ${totalVideoRequests.toLocaleString()}`);
  console.log(`   Cache Hits: ${totalCacheHits.toLocaleString()} (${totalVideoRequests > 0 ? ((totalCacheHits / totalVideoRequests) * 100).toFixed(1) : 0}%)`);
  console.log(`   Cache Misses: ${(totalVideoRequests - totalCacheHits).toLocaleString()}`);

  console.log('\n🎯 Batch Video API:');
  console.log(`   Total Batch Requests: ${totalBatchRequests.toLocaleString()}`);
  console.log(`   Videos Found: ${totalVideosFound.toLocaleString()}`);
  console.log(`   Videos Missing: ${totalVideosMissing.toLocaleString()}`);
  console.log(`   Success Rate: ${totalVideosFound + totalVideosMissing > 0 ? ((totalVideosFound / (totalVideosFound + totalVideosMissing)) * 100).toFixed(1) : 0}%`);

  // Quality breakdown
  console.log('\n📱 Quality Preferences:');
  const qualityStats = { '480p': 0, '720p': 0, 'both': 0 };
  
  summary.forEach(hourData => {
    const breakdown = hourData.videoMetadata?.qualityBreakdown || {};
    Object.entries(breakdown).forEach(([quality, count]) => {
      qualityStats[quality] = (qualityStats[quality] || 0) + count;
    });
  });

  const totalQualityRequests = Object.values(qualityStats).reduce((a, b) => a + b, 0);
  Object.entries(qualityStats).forEach(([quality, count]) => {
    const percentage = totalQualityRequests > 0 ? ((count / totalQualityRequests) * 100).toFixed(1) : 0;
    console.log(`   ${quality}: ${count.toLocaleString()} (${percentage}%)`);
  });

  // Error summary
  console.log('\n⚠️  Errors:');
  const errorCounts = {};
  
  summary.forEach(hourData => {
    const errors = hourData.errors || {};
    Object.entries(errors).forEach(([endpoint, statusCodes]) => {
      Object.entries(statusCodes).forEach(([code, count]) => {
        const key = `${endpoint} (${code})`;
        errorCounts[key] = (errorCounts[key] || 0) + count;
      });
    });
  });

  if (Object.keys(errorCounts).length === 0) {
    console.log('   No errors recorded! 🎉');
  } else {
    Object.entries(errorCounts).forEach(([key, count]) => {
      console.log(`   ${key}: ${count.toLocaleString()}`);
    });
  }

  console.log('\n' + '=' .repeat(60));
}

async function main() {
  const hours = parseInt(process.argv[2]) || 24;
  
  console.log(`Fetching analytics for the last ${hours} hours...`);
  
  const data = await fetchAnalytics(hours);
  
  if (!data.summary || data.summary.length === 0) {
    console.log('\nNo analytics data available for the specified time range.');
    return;
  }

  formatMetrics(data.summary);
  
  console.log(`\nLast updated: ${data.timestamp}`);
}

// Run the script
main().catch(console.error);