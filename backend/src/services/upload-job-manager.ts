// ABOUTME: Durable Object for managing upload job state and progress
// ABOUTME: Provides persistent state tracking for async video processing workflows

import { UploadJobStatus, NIP96UploadResponse } from '../types/nip96';

/**
 * Durable Object for managing upload job state
 * Handles job lifecycle from upload initiation to completion
 */
export class UploadJobManager implements DurableObject {
  private state: DurableObjectState;
  private env: Env;

  constructor(state: DurableObjectState, env: Env) {
    this.state = state;
    this.env = env;
  }

  /**
   * Handle HTTP requests to the Durable Object
   */
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const method = request.method;

    try {
      // Get job status
      if (method === 'GET' && path.startsWith('/job/')) {
        const jobId = path.split('/job/')[1];
        return await this.getJobStatus(jobId);
      }

      // Create new job
      if (method === 'POST' && path === '/job') {
        const jobData = await request.json();
        return await this.createJob(jobData);
      }

      // Update job status
      if (method === 'PUT' && path.startsWith('/job/')) {
        const jobId = path.split('/job/')[1];
        const updateData = await request.json();
        return await this.updateJob(jobId, updateData);
      }

      // Complete job
      if (method === 'POST' && path.startsWith('/job/') && path.endsWith('/complete')) {
        const jobId = path.split('/job/')[1].replace('/complete', '');
        const completionData = await request.json();
        return await this.completeJob(jobId, completionData);
      }

      // Fail job
      if (method === 'POST' && path.startsWith('/job/') && path.endsWith('/fail')) {
        const jobId = path.split('/job/')[1].replace('/fail', '');
        const errorData = await request.json();
        return await this.failJob(jobId, errorData);
      }

      // List jobs (for debugging/admin)
      if (method === 'GET' && path === '/jobs') {
        return await this.listJobs();
      }

      return new Response('Not Found', { status: 404 });

    } catch (error) {
      console.error('UploadJobManager error:', error);
      return new Response('Internal Server Error', { status: 500 });
    }
  }

  /**
   * Create a new upload job
   */
  private async createJob(jobData: {
    job_id: string;
    file_name: string;
    content_type: string;
    file_size: number;
    user_id?: string;
    metadata?: Record<string, any>;
  }): Promise<Response> {
    const job: UploadJobStatus = {
      job_id: jobData.job_id,
      status: 'pending',
      progress: 0,
      message: 'Upload job created',
      created_at: Date.now(),
      updated_at: Date.now()
    };

    await this.state.storage.put(jobData.job_id, job);
    
    // Set expiration for job cleanup (24 hours)
    await this.state.storage.setAlarm(Date.now() + 24 * 60 * 60 * 1000);

    return new Response(JSON.stringify(job), {
      status: 201,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  /**
   * Get job status
   */
  private async getJobStatus(jobId: string): Promise<Response> {
    const job = await this.state.storage.get<UploadJobStatus>(jobId);
    
    if (!job) {
      return new Response(JSON.stringify({
        error: 'Job not found',
        job_id: jobId
      }), {
        status: 404,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    return new Response(JSON.stringify(job), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  /**
   * Update job progress/status
   */
  private async updateJob(jobId: string, updateData: {
    status?: UploadJobStatus['status'];
    progress?: number;
    message?: string;
  }): Promise<Response> {
    const job = await this.state.storage.get<UploadJobStatus>(jobId);
    
    if (!job) {
      return new Response('Job not found', { status: 404 });
    }

    const updatedJob: UploadJobStatus = {
      ...job,
      ...updateData,
      updated_at: Date.now()
    };

    await this.state.storage.put(jobId, updatedJob);

    return new Response(JSON.stringify(updatedJob), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  /**
   * Mark job as completed with result
   */
  private async completeJob(jobId: string, completionData: {
    result: NIP96UploadResponse;
    processing_time?: number;
  }): Promise<Response> {
    const job = await this.state.storage.get<UploadJobStatus>(jobId);
    
    if (!job) {
      return new Response('Job not found', { status: 404 });
    }

    const completedJob: UploadJobStatus = {
      ...job,
      status: 'completed',
      progress: 100,
      message: 'Upload processing completed successfully',
      result: completionData.result,
      updated_at: Date.now()
    };

    await this.state.storage.put(jobId, completedJob);

    // Track completion analytics
    if (this.env.UPLOAD_ANALYTICS) {
      this.env.UPLOAD_ANALYTICS.writeDataPoint({
        'blobs': ['job_completed'],
        'doubles': [completionData.processing_time || 0],
        'indexes': [jobId]
      });
    }

    return new Response(JSON.stringify(completedJob), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  /**
   * Mark job as failed with error
   */
  private async failJob(jobId: string, errorData: {
    error: string;
    details?: string;
  }): Promise<Response> {
    const job = await this.state.storage.get<UploadJobStatus>(jobId);
    
    if (!job) {
      return new Response('Job not found', { status: 404 });
    }

    const failedJob: UploadJobStatus = {
      ...job,
      status: 'failed',
      message: 'Upload processing failed',
      error: errorData.error,
      updated_at: Date.now()
    };

    await this.state.storage.put(jobId, failedJob);

    // Track failure analytics
    if (this.env.UPLOAD_ANALYTICS) {
      this.env.UPLOAD_ANALYTICS.writeDataPoint({
        'blobs': ['job_failed', errorData.error],
        'indexes': [jobId]
      });
    }

    return new Response(JSON.stringify(failedJob), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  /**
   * List all jobs (for debugging)
   */
  private async listJobs(): Promise<Response> {
    const jobs = await this.state.storage.list<UploadJobStatus>();
    const jobList = Array.from(jobs.values());

    return new Response(JSON.stringify({
      total: jobList.length,
      jobs: jobList.slice(0, 50) // Limit to 50 most recent
    }), {
      headers: { 'Content-Type': 'application/json' }
    });
  }

  /**
   * Cleanup expired jobs
   */
  async alarm(): Promise<void> {
    const cutoffTime = Date.now() - 24 * 60 * 60 * 1000; // 24 hours ago
    const jobs = await this.state.storage.list<UploadJobStatus>();

    let deletedCount = 0;
    for (const [jobId, job] of jobs) {
      // Delete completed or failed jobs older than 24 hours
      if (job.updated_at < cutoffTime && 
          (job.status === 'completed' || job.status === 'failed')) {
        await this.state.storage.delete(jobId);
        deletedCount++;
      }
    }

    console.log(`Cleaned up ${deletedCount} expired upload jobs`);

    // Set next alarm
    await this.state.storage.setAlarm(Date.now() + 24 * 60 * 60 * 1000);
  }
}

/**
 * Helper function to get job manager instance
 */
export async function getJobManager(
  jobId: string, 
  env: Env
): Promise<DurableObjectStub> {
  const id = env.UPLOAD_JOBS.idFromName(jobId);
  return env.UPLOAD_JOBS.get(id);
}

/**
 * Create a new upload job
 */
export async function createUploadJob(
  jobData: {
    job_id: string;
    file_name: string;
    content_type: string;
    file_size: number;
    user_id?: string;
    metadata?: Record<string, any>;
  },
  env: Env
): Promise<UploadJobStatus> {
  const jobManager = await getJobManager(jobData.job_id, env);
  const response = await jobManager.fetch('https://internal/job', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(jobData)
  });

  return await response.json();
}

/**
 * Update upload job status
 */
export async function updateUploadJob(
  jobId: string,
  updateData: {
    status?: UploadJobStatus['status'];
    progress?: number;
    message?: string;
  },
  env: Env
): Promise<UploadJobStatus> {
  const jobManager = await getJobManager(jobId, env);
  const response = await jobManager.fetch(`https://internal/job/${jobId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(updateData)
  });

  return await response.json();
}

/**
 * Complete upload job
 */
export async function completeUploadJob(
  jobId: string,
  result: NIP96UploadResponse,
  env: Env
): Promise<UploadJobStatus> {
  const jobManager = await getJobManager(jobId, env);
  const response = await jobManager.fetch(`https://internal/job/${jobId}/complete`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ result })
  });

  return await response.json();
}

/**
 * Fail upload job
 */
export async function failUploadJob(
  jobId: string,
  error: string,
  details?: string,
  env: Env
): Promise<UploadJobStatus> {
  const jobManager = await getJobManager(jobId, env);
  const response = await jobManager.fetch(`https://internal/job/${jobId}/fail`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ error, details })
  });

  return await response.json();
}