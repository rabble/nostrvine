// ABOUTME: Internal result categories for a signed video-event publish attempt.
// ABOUTME: Separates publish success from retryable transport failures.

part of '../services/video_event_publisher.dart';

enum _EventPublishOutcome { published, transientFailure }
