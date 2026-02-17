package co.openvine.app.proofmode

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import org.witness.proofmode.notarization.NotarizationListener
import org.witness.proofmode.notarization.NotarizationProvider
import java.io.InputStream
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.cert.X509Certificate

class HardwareAttestationNotarizationProvider (_context: Context) : NotarizationProvider {

    init {
        val context = _context
    }

    override fun notarize(
        proofHash: String?,
        stream: InputStream?,
        listener: NotarizationListener?
    ) {


        proofHash?.let {
            var deviceAttestation = completeDeviceAttestation(proofHash)
            if (deviceAttestation != null) {
               listener?.notarizationSuccessful(proofHash, deviceAttestation)
            }
            else
                listener?.notarizationFailed(-1,proofHash)
        }

    }

    override fun getProof(p0: String?): String? {
        TODO("Not yet implemented")
    }

    override fun getNotarizationFileExtension(): String? {
        return ".attest"
    }

    //generate a local hardware-back signature with the nonce of the sha256 ingredient image inside of it
    //https://proandroiddev.com/your-app-is-secure-but-is-the-device-android-hardware-attestation-explained-e9a531312035
    private fun completeDeviceAttestation (nonceOfIngredient: String) : String? {

        val keyAlias = "attested_key_${nonceOfIngredient}"
        val keyGen = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore"
        )

        val spec = KeyGenParameterSpec.Builder(
            keyAlias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
        )
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setAttestationChallenge(nonceOfIngredient.toByteArray())        // request attestation
            .build()

        keyGen.initialize(spec)

        //create temp key with Nonce
        val keyPair = keyGen.generateKeyPair()
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

        val certChain = ks.getCertificateChain(keyAlias)

        if (certChain != null)
        {
            var sb = StringBuilder()

            for (cert in certChain)
            {
                var xCert = cert as X509Certificate
                sb.append(xCert.toString())
                sb.append("\n\n");
            }

            //and poof it is gone - no need to keep it stored locally
            ks.deleteEntry(keyAlias)

            return sb.toString()
        }
        else
        {
            return null
        }
    }
}