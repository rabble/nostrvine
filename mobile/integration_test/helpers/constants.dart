// ABOUTME: Shared constants for E2E integration tests
// ABOUTME: Re-exports environment config constants (FunnelCake, indexer, external relay ports)

export 'package:openvine/models/environment_config.dart'
    show
        localApiPort,
        localBlossomPort,
        localExternalRelayPort,
        localHost,
        localIndexerRelayPort,
        localInvitePort,
        localKeycastPort,
        localRelayPort;

/// Postgres port (mapped from docker-compose: 15432:5432)
const pgPort = 15432;

/// Android app package name for adb commands
const appPackage = 'co.openvine.app';
