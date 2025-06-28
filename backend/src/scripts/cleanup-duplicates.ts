// ABOUTME: Script to clean up duplicate files in R2 and build SHA256 index
// ABOUTME: Groups files by SHA256 hash, keeps oldest, deletes duplicates

import { MetadataStore } from '../services/metadata-store';

interface FileInfo {
  key: string;
  fileId: string;
  sha256: string;
  uploadedAt: number;
  size: number;
}

/**
 * Clean up duplicate files in R2 storage with batching
 */
export async function cleanupDuplicates(env: Env, options: { limit?: number; dryRun?: boolean } = {}): Promise<{
  totalFiles: number;
  duplicatesFound: number;
  bytesFreed: number;
  indexEntriesCreated: number;
  processed: number;
}> {
  console.log('🧹 Starting duplicate cleanup process...');
  
  if (!env.MEDIA_BUCKET || !env.METADATA_CACHE) {
    throw new Error('Required bindings not available');
  }

  const metadataStore = new MetadataStore(env.METADATA_CACHE);
  const { limit = 100, dryRun = false } = options;
  
  // Track statistics
  let totalFiles = 0;
  let duplicatesFound = 0;
  let bytesFreed = 0;
  let indexEntriesCreated = 0;
  let processed = 0;

  // Group files by SHA256
  const filesBySha256 = new Map<string, FileInfo[]>();
  
  try {
    // List files with a reasonable limit to avoid rate limits
    const listResult = await env.MEDIA_BUCKET.list({
      prefix: 'uploads/',
      limit: limit
    });
    
    // Process files in smaller batches to avoid rate limits
    const batchSize = 10;
    const objects = listResult.objects || [];
    
    for (let i = 0; i < objects.length; i += batchSize) {
      const batch = objects.slice(i, i + batchSize);
      
      // Process batch in parallel
      const batchPromises = batch.map(async (object) => {
        totalFiles++;
        
        try {
          // Get object metadata to extract SHA256
          const headResult = await env.MEDIA_BUCKET.head(object.key);
          if (!headResult || !headResult.customMetadata?.sha256) {
            console.warn(`⚠️ No SHA256 found for ${object.key}, skipping`);
            return;
          }
          
          const sha256 = headResult.customMetadata.sha256;
          const fileId = headResult.customMetadata.fileId || object.key.replace('uploads/', '').replace('.mp4', '');
          const uploadedAt = parseInt(headResult.customMetadata.uploadedAt || '0') || object.uploaded.getTime();
          
          const fileInfo: FileInfo = {
            key: object.key,
            fileId,
            sha256,
            uploadedAt,
            size: object.size
          };
          
          if (!filesBySha256.has(sha256)) {
            filesBySha256.set(sha256, []);
          }
          filesBySha256.get(sha256)!.push(fileInfo);
        } catch (error) {
          console.error(`Failed to process ${object.key}:`, error);
        }
      });
      
      await Promise.all(batchPromises);
      
      // Small delay between batches to avoid rate limits
      if (i + batchSize < objects.length) {
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }
    
    console.log(`📊 Found ${totalFiles} total files`);
    console.log(`🔍 Grouped into ${filesBySha256.size} unique SHA256 hashes`);
    
    // Process each SHA256 group with rate limiting
    for (const [sha256, files] of filesBySha256) {
      processed++;
      
      if (files.length === 1) {
        // No duplicates, just ensure index exists
        const file = files[0];
        try {
          const existing = await metadataStore.getFileIdBySha256(sha256);
          if (!existing) {
            await metadataStore.setFileIdBySha256(sha256, file.fileId);
            indexEntriesCreated++;
          }
        } catch (error) {
          console.error(`Failed to create index for ${file.key}:`, error);
        }
        continue;
      }
      
      // Found duplicates
      console.log(`🔄 Found ${files.length} files with SHA256 ${sha256}`);
      duplicatesFound += files.length - 1;
      
      // Sort by upload time (oldest first)
      files.sort((a, b) => a.uploadedAt - b.uploadedAt);
      
      // Keep the oldest file
      const keeper = files[0];
      console.log(`✅ Keeping ${keeper.key} (oldest, uploaded ${new Date(keeper.uploadedAt).toISOString()})`);
      
      // Store SHA256 mapping for keeper
      try {
        await metadataStore.setFileIdBySha256(sha256, keeper.fileId);
        indexEntriesCreated++;
      } catch (error) {
        console.error(`Failed to store SHA256 mapping:`, error);
      }
      
      // Delete duplicates (unless dry run)
      if (!dryRun) {
        for (let i = 1; i < files.length; i++) {
          const duplicate = files[i];
          console.log(`🗑️ Deleting duplicate ${duplicate.key}`);
          
          try {
            await env.MEDIA_BUCKET.delete(duplicate.key);
            bytesFreed += duplicate.size;
          } catch (error) {
            console.error(`❌ Failed to delete ${duplicate.key}:`, error);
          }
        }
      } else {
        // Dry run - just calculate bytes that would be freed
        for (let i = 1; i < files.length; i++) {
          bytesFreed += files[i].size;
        }
      }
    }
    
    // Summary
    const summary = {
      totalFiles,
      duplicatesFound,
      bytesFreed,
      indexEntriesCreated,
      processed
    };
    
    console.log('\n📈 Cleanup Summary:');
    console.log(`✅ Total files processed: ${totalFiles}`);
    console.log(`🔄 Duplicates ${dryRun ? 'found' : 'removed'}: ${duplicatesFound}`);
    console.log(`💾 Storage ${dryRun ? 'to be freed' : 'freed'}: ${(bytesFreed / 1024 / 1024).toFixed(2)} MB`);
    console.log(`📑 Index entries created: ${indexEntriesCreated}`);
    if (dryRun) {
      console.log(`⚠️ DRY RUN - No files were actually deleted`);
    }
    
    return summary;
    
  } catch (error) {
    console.error('❌ Cleanup failed:', error);
    throw error;
  }
}

/**
 * Handler for manual cleanup trigger
 */
export async function handleCleanupRequest(request: Request, env: Env): Promise<Response> {
  try {
    // Use webhook secret for simple authentication
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response('Unauthorized - Bearer token required', { status: 401 });
    }
    
    const token = authHeader.substring(7); // Remove "Bearer " prefix
    
    // Check against webhook secret (in production, use a dedicated admin token)
    if (token !== env.WEBHOOK_SECRET) {
      return new Response('Invalid token', { status: 403 });
    }
    
    console.log('🔐 Admin cleanup request authorized');
    
    // Parse query parameters
    const url = new URL(request.url);
    const limit = parseInt(url.searchParams.get('limit') || '50');
    const dryRun = url.searchParams.get('dryRun') === 'true';
    
    console.log(`📋 Cleanup parameters: limit=${limit}, dryRun=${dryRun}`);
    
    const results = await cleanupDuplicates(env, { limit, dryRun });
    
    return new Response(JSON.stringify({
      status: 'success',
      message: dryRun ? 'Dry run completed' : 'Duplicate cleanup completed',
      results: {
        filesProcessed: results.totalFiles,
        duplicatesFound: results.duplicatesFound,
        storageFreeeMB: (results.bytesFreed / 1024 / 1024).toFixed(2),
        indexEntriesCreated: results.indexEntriesCreated,
        dryRun
      }
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
    
  } catch (error) {
    console.error('Cleanup request failed:', error);
    return new Response(JSON.stringify({
      status: 'error',
      message: error instanceof Error ? error.message : 'Unknown error'
    }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
}