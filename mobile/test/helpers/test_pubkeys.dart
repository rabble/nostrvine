// ABOUTME: Shared synthetic pubkeys for test fixtures.
// ABOUTME: Never use a real personal key as test data.

/// A clearly-synthetic 64-char hex pubkey for use as a generic fixture
/// identity in tests (test video author, mock current-user pubkey, and
/// similar).
///
/// Replaces the real personal key that #5963 removed from production code
/// but which lingered as scattered literals across test files
/// (#6083 / support-trust-safety#184). `deadbeef` repeated is unmistakably
/// fake yet a valid lowercase 64-char hex that round-trips through npub
/// encode/decode.
const syntheticTestPubkey =
    'deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef';

/// A second clearly-synthetic pubkey, distinct from [syntheticTestPubkey], for
/// tests that need two different fixture identities (e.g. "me" vs "not me").
const syntheticOtherTestPubkey =
    'cafebabecafebabecafebabecafebabecafebabecafebabecafebabecafebabe';
