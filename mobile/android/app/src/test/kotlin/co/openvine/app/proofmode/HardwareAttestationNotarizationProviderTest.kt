package co.openvine.app.proofmode

import io.mockk.mockk
import org.junit.Assert.assertNull
import org.junit.Test

class HardwareAttestationNotarizationProviderTest {

    @Test
    fun `getProof returns null when no cached proof is available`() {
        val provider = HardwareAttestationNotarizationProvider(mockk(relaxed = true))

        assertNull(provider.getProof("missing-proof-hash"))
    }

    @Test
    fun `getProof returns null for a null proof hash`() {
        val provider = HardwareAttestationNotarizationProvider(mockk(relaxed = true))

        assertNull(provider.getProof(null))
    }
}
