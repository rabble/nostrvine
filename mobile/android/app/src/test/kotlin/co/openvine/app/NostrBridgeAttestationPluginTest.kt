package co.openvine.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Native coverage for the Nostr bridge frame-attestation plugin's pure logic,
 * mirroring the iOS `RunnerTests.swift`. The two pieces below are the
 * security-relevant logic the Dart-side tests cannot cover:
 *
 *   1. The single-instance attach/detach state machine — if a second attach
 *      silently won, the first sandbox would stop receiving attested events and
 *      degrade to nonce-only with no signal.
 *   2. The {message, isMainFrame} payload contract delivered to Dart — if it
 *      regresses or grows fields, downstream callers may rely on data the
 *      contract no longer guarantees.
 *
 * Both are pure, so they run on the plain JVM without a real WebView or
 * FlutterEngine. (The iOS `WebKitContentControllerIntegrationTests` smoke test
 * has no clean JVM analog — Robolectric's WebView shadow does not implement
 * WebViewCompat — so that proof lives in the manual on-device test plan.)
 */
class NostrBridgeAttestationPolicyTest {
    @Test
    fun `initial state has no attachment`() {
        val policy = NostrBridgeAttestationPolicy()
        assertNull(policy.attachedWebViewId)
    }

    @Test
    fun `attach returns Ok when nothing attached`() {
        val policy = NostrBridgeAttestationPolicy()
        assertEquals(NostrBridgeAttestationPolicy.AttachResult.Ok, policy.attach(1))
        assertEquals(1L, policy.attachedWebViewId)
    }

    @Test
    fun `attach is idempotent for the same webViewId`() {
        val policy = NostrBridgeAttestationPolicy()
        policy.attach(7)
        assertEquals(NostrBridgeAttestationPolicy.AttachResult.NoOp, policy.attach(7))
        assertEquals(7L, policy.attachedWebViewId)
    }

    @Test
    fun `attach refuses a different webViewId while one is attached`() {
        val policy = NostrBridgeAttestationPolicy()
        policy.attach(1)
        assertEquals(
            NostrBridgeAttestationPolicy.AttachResult.AlreadyAttached(1),
            policy.attach(2),
        )
        assertEquals(
            "second attach must not overwrite the existing attachment",
            1L,
            policy.attachedWebViewId,
        )
    }

    @Test
    fun `detach clears a matching attachment`() {
        val policy = NostrBridgeAttestationPolicy()
        policy.attach(9)
        assertTrue(policy.detach(9))
        assertNull(policy.attachedWebViewId)
    }

    @Test
    fun `detach is a no-op for an unattached webViewId`() {
        val policy = NostrBridgeAttestationPolicy()
        policy.attach(1)
        assertFalse(policy.detach(2))
        assertEquals(
            "stale detach call must not clear the live attachment",
            1L,
            policy.attachedWebViewId,
        )
    }

    @Test
    fun `detach is a no-op when nothing is attached`() {
        val policy = NostrBridgeAttestationPolicy()
        assertFalse(policy.detach(1))
        assertNull(policy.attachedWebViewId)
    }

    @Test
    fun `re-attach after detach succeeds`() {
        val policy = NostrBridgeAttestationPolicy()
        policy.attach(1)
        policy.detach(1)
        assertEquals(NostrBridgeAttestationPolicy.AttachResult.Ok, policy.attach(2))
        assertEquals(2L, policy.attachedWebViewId)
    }
}

class AttestationEventPayloadTest {
    @Test
    fun `payload includes the message body`() {
        val payload = attestationEventPayload("hello", isMainFrame = true)
        assertEquals("hello", payload["message"])
    }

    @Test
    fun `payload includes isMainFrame true`() {
        val payload = attestationEventPayload("x", isMainFrame = true)
        assertEquals(true, payload["isMainFrame"])
    }

    @Test
    fun `payload includes isMainFrame false`() {
        val payload = attestationEventPayload("x", isMainFrame = false)
        assertEquals(false, payload["isMainFrame"])
    }

    @Test
    fun `payload has only message and isMainFrame keys`() {
        val payload = attestationEventPayload("x", isMainFrame = true)
        assertEquals(
            "payload must not leak sourceOrigin or any other field — " +
                "Dart only consumes message + isMainFrame",
            setOf("message", "isMainFrame"),
            payload.keys,
        )
    }
}
