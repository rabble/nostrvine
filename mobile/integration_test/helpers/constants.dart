// ABOUTME: Shared constants for E2E integration tests
// ABOUTME: Host addresses, ports, and package names for the local Docker stack

/// Host address from Android emulator. The emulator's 10.0.2.2 maps to the
/// host machine's localhost, where the Docker stack is running.
const emulatorHost = '10.0.2.2';

/// Keycast port (mapped from docker-compose: 43000:3000)
const keycastPort = 43000;

/// Postgres port (mapped from docker-compose: 15432:5432)
const pgPort = 15432;

/// FunnelCake relay WebSocket port (mapped from docker-compose: 47777:7777)
const relayPort = 47777;

/// Blossom media server port (mapped from docker-compose: 43003:3000)
const blossomPort = 43003;

/// Android app package name for adb commands
const appPackage = 'co.openvine.app';
