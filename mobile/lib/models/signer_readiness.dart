// ABOUTME: Models whether the active identity can sign now or may sign later.
// ABOUTME: Distinguishes signer warm-up from permanent unavailability.

enum SignerReadiness { pending, ready, unavailable }
