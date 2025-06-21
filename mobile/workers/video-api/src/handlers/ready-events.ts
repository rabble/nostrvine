// ABOUTME: Handles client polling for ready Nostr events after video processing
// ABOUTME: Allows clients to retrieve prepared NIP-94 events for signing and publishing

import { Env, ExecutionContext } from '../types';
import { validateNIP98Event, NIP98AuthError } from '../lib/auth';

interface ReadyEvent {
  public_id: string;
  tags: string[][];
  content_suggestion: string;
  formats: {
    mp4?: string;
    webp?: string;
    gif?: string;
    original?: string;
  };
  metadata: {
    width: number;
    height: number;
    duration?: number;
    size_bytes: number;
  };
  timestamp: string;
}

interface ReadyEventsResponse {
  events: ReadyEvent[];
  count: number;
}

interface DeleteEventRequest {
  public_id: string;
}

export class ReadyEventsHandler {
  private env: Env;

  constructor(env: Env) {
    this.env = env;
  }

  /**
   * GET /v1/media/ready-events
   * Returns ready events for the authenticated user
   */
  async handleGetReadyEvents(request: Request, ctx: ExecutionContext): Promise<Response> {
    try {
      // Validate NIP-98 authentication
      const authHeader = request.headers.get('Authorization');
      if (!authHeader) {
        return this.errorResponse('Missing Authorization header', 401);
      }

      let nostrEvent;
      try {
        nostrEvent = await validateNIP98Event(authHeader, request.url, 'GET');
      } catch (error) {
        if (error instanceof NIP98AuthError) {
          return this.errorResponse(error.message, 401);
        }
        throw error;
      }

      const pubkey = nostrEvent.pubkey;

      // List all ready events for this pubkey
      const prefix = `ready:${pubkey}:`;
      const list = await this.env.VIDEO_STATUS.list({ prefix });

      const events: ReadyEvent[] = [];
      
      // Fetch each event
      for (const key of list.keys) {
        const data = await this.env.VIDEO_STATUS.get(key.name);
        if (data) {
          try {
            const event = JSON.parse(data) as ReadyEvent;
            events.push(event);
          } catch (error) {
            console.error(`Error parsing ready event ${key.name}:`, error);
          }
        }
      }

      // Sort by timestamp (newest first)
      events.sort((a, b) => 
        new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
      );

      const response: ReadyEventsResponse = {
        events,
        count: events.length
      };

      return new Response(JSON.stringify(response), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate'
        }
      });

    } catch (error) {
      console.error('Error handling ready events request:', error);
      return this.errorResponse('Internal server error', 500);
    }
  }

  /**
   * DELETE /v1/media/ready-events
   * Removes a ready event after client has processed it
   */
  async handleDeleteReadyEvent(request: Request, ctx: ExecutionContext): Promise<Response> {
    try {
      // Validate NIP-98 authentication
      const authHeader = request.headers.get('Authorization');
      if (!authHeader) {
        return this.errorResponse('Missing Authorization header', 401);
      }

      let nostrEvent;
      try {
        nostrEvent = await validateNIP98Event(authHeader, request.url, 'DELETE');
      } catch (error) {
        if (error instanceof NIP98AuthError) {
          return this.errorResponse(error.message, 401);
        }
        throw error;
      }

      const pubkey = nostrEvent.pubkey;

      // Parse request body
      const body = await this.parseRequestBody<DeleteEventRequest>(request);
      if (!body || !body.public_id) {
        return this.errorResponse('Missing public_id in request body', 400);
      }

      // Delete the ready event
      const key = `ready:${pubkey}:${body.public_id}`;
      await this.env.VIDEO_STATUS.delete(key);

      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: {
          'Content-Type': 'application/json'
        }
      });

    } catch (error) {
      console.error('Error handling delete ready event:', error);
      return this.errorResponse('Internal server error', 500);
    }
  }

  /**
   * GET /v1/media/ready-events/:public_id
   * Get a specific ready event by public_id
   */
  async handleGetSpecificEvent(
    request: Request, 
    publicId: string,
    ctx: ExecutionContext
  ): Promise<Response> {
    try {
      // Validate NIP-98 authentication
      const authHeader = request.headers.get('Authorization');
      if (!authHeader) {
        return this.errorResponse('Missing Authorization header', 401);
      }

      let nostrEvent;
      try {
        nostrEvent = await validateNIP98Event(authHeader, request.url, 'GET');
      } catch (error) {
        if (error instanceof NIP98AuthError) {
          return this.errorResponse(error.message, 401);
        }
        throw error;
      }

      const pubkey = nostrEvent.pubkey;

      // Get the specific event
      const key = `ready:${pubkey}:${publicId}`;
      const data = await this.env.VIDEO_STATUS.get(key);

      if (!data) {
        return this.errorResponse('Event not found', 404);
      }

      const event = JSON.parse(data) as ReadyEvent;

      return new Response(JSON.stringify(event), {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate'
        }
      });

    } catch (error) {
      console.error('Error handling get specific event:', error);
      return this.errorResponse('Internal server error', 500);
    }
  }

  private async parseRequestBody<T>(request: Request): Promise<T | null> {
    try {
      const contentType = request.headers.get('content-type');
      if (!contentType?.includes('application/json')) {
        return null;
      }

      const body = await request.json() as T;
      return body;
    } catch {
      return null;
    }
  }

  private errorResponse(message: string, status: number): Response {
    return new Response(
      JSON.stringify({ error: { message } }),
      {
        status,
        headers: {
          'Content-Type': 'application/json'
        }
      }
    );
  }
}