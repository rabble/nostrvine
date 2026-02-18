package co.openvine.app.proofmode

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.WrappedKeyEntry
import android.util.Base64
import android.util.Log
import org.contentauth.c2pa.CertificateManager
import org.contentauth.c2pa.KeyStoreSigner
import org.contentauth.c2pa.Signer
import org.contentauth.c2pa.SigningAlgorithm
import org.contentauth.c2pa.StrongBoxSigner
import java.io.File
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.interfaces.ECPrivateKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Date
import javax.crypto.Cipher
import javax.security.auth.x500.X500Principal

class C2PAIdentityManager(private val context: Context) {
    companion object {
        private const val TAG = "C2PAManager"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEYSTORE_ALIAS_PREFIX = "C2PA_KEY_"

        /**
        private val iso8601 = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }**/

        public const val TSA_DIGICERT = "http://timestamp.digicert.com"
        public const val TSA_SSLCOM = "https://api.c2patool.io/api/v1/timestamps/ecc"
    }

    private var defaultSigner: Signer? = null

    public suspend fun createKeystoreSigner(tsaUrl: String): Signer {
        val keyAlias = "C2PA_SOFTWARE_KEY_SECURE"
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)

        var certChain = ""

        // Create or get the keystore key
        if (!keyStore.containsAlias(keyAlias)) {
           // Timber.d( "Creating new keystore key")
            createKeystoreKey(keyAlias, false)

            // Get certificate chain from signing server
            certChain = enrollHardwareKeyCertificate(keyAlias)

            var fileCert = File(context.filesDir,"$keyAlias.cert")
            fileCert.writeText(certChain)
        }
        else{
            // Get certificate chain from signing server

            val fileCert = File(context.filesDir,"$keyAlias.cert")
            if (fileCert.exists())
                certChain = fileCert.readText()
            else {
                certChain = enrollHardwareKeyCertificate(keyAlias)
                fileCert.writeText(certChain)
            }

        }


       // Timber.d( "Using KeyStoreSigner with keyAlias: $keyAlias")

        // Use the new KeyStoreSigner class
        return KeyStoreSigner.createSigner(
            algorithm = SigningAlgorithm.ES256,
            certificateChainPEM = certChain,
            keyAlias = keyAlias,
            tsaURL = tsaUrl
        )
    }


    public suspend fun createHardwareSigner(keyAlias: String, tsaUrl: String, certPath: String): Signer? {

        // Get or create hardware-backed key
        val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)

        var certChain : String = ""

        if (!keyStore.containsAlias(keyAlias)) {
          //  Timber.d( "Creating new hardware-backed key with StrongBox if available")

            // Create StrongBox config
            val config = StrongBoxSigner.Config(keyTag = keyAlias, requireUserAuthentication = false)

            // Create key using StrongBoxSigner (will use StrongBox if available, TEE otherwise)
            try {
                StrongBoxSigner.createKey(config)
            } catch (e: Exception) {
             //   Timber.d( "StrongBox key creation failed, falling back to software-backed key")
                createKeystoreKey(keyAlias, false)
            }
            // Get certificate chain from signing server
            certChain = enrollHardwareKeyCertificate(keyAlias)

            var fileCert = File(certPath)
            fileCert.writeText(certChain)
        }

        else{
            // Get certificate chain from signing server

            val fileCert = File(certPath)
            if (fileCert.exists())
                certChain = fileCert.readText()
            else {
                // Get certificate chain from signing server
                certChain = enrollHardwareKeyCertificate(keyAlias)
                var fileCert = File(certPath)
                fileCert.writeText(certChain)
            }

        }


        if (certChain.isNotEmpty()) {
         //   Timber.d("Creating StrongBoxSigner")

            // Create StrongBox config
            val config = StrongBoxSigner.Config(keyTag = keyAlias, requireUserAuthentication = false)

            // Use the new StrongBoxSigner class
            return StrongBoxSigner.createSigner(
                algorithm = SigningAlgorithm.ES256,
                certificateChainPEM = certChain,
                config = config,
                tsaURL = tsaUrl
            )
        }
        else
            return null
    }


    private fun createKeystoreKey(alias: String, useHardware: Boolean) {
        val keyPairGenerator =
            KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE)

        val paramSpec =
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY,
            )
                .apply {
                    setDigests(KeyProperties.DIGEST_SHA256)
                    setAlgorithmParameterSpec(
                        ECGenParameterSpec("secp256r1"),
                    )

                    if (useHardware) {
                        // Request hardware backing (StrongBox if available, TEE otherwise)
                        if (Build.VERSION.SDK_INT >=
                            Build.VERSION_CODES.P
                        ) {
                            setIsStrongBoxBacked(true)
                        }
                    }

                    // Self-signed certificate validity
                    setCertificateSubject(
                        X500Principal("CN=C2PA Android User, O=C2PA Example, C=US"),
                    )
                    setCertificateSerialNumber(
                        BigInteger.valueOf(System.currentTimeMillis()),
                    )
                    setCertificateNotBefore(Date())
                    setCertificateNotAfter(
                        Date(System.currentTimeMillis() + 365L * 24 * 60 * 60 * 1000),
                    )
                }
                .build()

        keyPairGenerator.initialize(paramSpec)
        keyPairGenerator.generateKeyPair()
    }

    private suspend fun enrollHardwareKeyCertificate(alias: String): String {

        // Generate CSR for the hardware key
        val csr = generateCSR(alias)

        // Submit CSR to signing server
        val csrResp = CertificateSigningService().signCSR(csr)
        val certChain = csrResp.certificate_chain
        val certId = csrResp.certificate_id

    //    Timber.d( "Certificate enrolled successfully. ID: $certId")

        return certChain
    }

    private fun generateCSR(alias: String): String {
        try {
            // Use the library's CertificateManager to generate a proper CSR
            val config =
                CertificateManager.CertificateConfig(
                    commonName = "DiVine Proofmode C2PA Hardware Key",
                    organization = "DiVine App Proofmode Self-Signed",
                    organizationalUnit = "Mobile",
                    country = "US",
                    state = "New York",
                    locality = "New York",
                )

            // Generate CSR using the library
            val csr = CertificateManager.createCSR(alias, config)

         //   Timber.d( "Generated proper CSR for alias $alias")
            return csr
        } catch (e: Exception) {
            Log.e(TAG, "Failed to generate CSR", e)
            throw RuntimeException("Failed to generate CSR: ${e.message}", e)
        }
    }

    /** Import key using Secure Key Import (API 28+) Throws exception if import fails */
    private fun importKeySecurely(keyAlias: String, privateKeyPEM: String) {
        try {
          //  Timber.d( "Starting key import for alias: $keyAlias")
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
            keyStore.load(null)

            // Parse the private key from PEM
            val privateKeyBytes = parsePrivateKeyFromPEM(privateKeyPEM)
            val keyFactory = KeyFactory.getInstance("EC")
            val privateKey =
                keyFactory.generatePrivate(PKCS8EncodedKeySpec(privateKeyBytes)) as
                    ECPrivateKey

          //  Timber.d( "Private key parsed, algorithm: ${privateKey.algorithm}")

            // Create wrapping key for import (using ENCRYPT/DECRYPT which is more widely supported)
            val wrappingKeyAlias = "${keyAlias}_WRAPPER_TEMP"

            // Clean up any existing wrapper key
            if (keyStore.containsAlias(wrappingKeyAlias)) {
                keyStore.deleteEntry(wrappingKeyAlias)
            }

            // Generate RSA wrapping key with ENCRYPT purpose (more compatible than WRAP_KEY)
            val keyGenSpec =
                KeyGenParameterSpec.Builder(
                    wrappingKeyAlias,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setKeySize(2048)
                    .setBlockModes(KeyProperties.BLOCK_MODE_ECB)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
                    .setDigests(KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA1)
                    .build()

            val keyPairGenerator =
                KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, ANDROID_KEYSTORE)
            keyPairGenerator.initialize(keyGenSpec)
            val wrappingKeyPair = keyPairGenerator.generateKeyPair()
       //     Timber.d( "Wrapping key generated")

            // Get the public key for wrapping
            val publicKey = wrappingKeyPair.public

            // Wrap the private key
            val cipher = Cipher.getInstance("RSA/ECB/OAEPPadding")
            cipher.init(Cipher.WRAP_MODE, publicKey)
            val wrappedKeyBytes = cipher.wrap(privateKey)
          //  Timber.d( "Key wrapped, bytes length: ${wrappedKeyBytes.size}")

            // Import using WrappedKeyEntry
            val importSpec =
                KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_SIGN)
                    .setAlgorithmParameterSpec(
                        ECGenParameterSpec("secp256r1"),
                    )
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .build()

            val wrappedKeyEntry =
                WrappedKeyEntry(
                    wrappedKeyBytes,
                    wrappingKeyAlias,
                    "RSA/ECB/OAEPPadding",
                    importSpec,
                )

            keyStore.setEntry(keyAlias, wrappedKeyEntry, null)
          //  Timber.d( "Key imported to keystore")

            // Clean up wrapping key
            keyStore.deleteEntry(wrappingKeyAlias)

            // Verify import
            if (keyStore.containsAlias(keyAlias)) {
             ///   Timber.d( "Key successfully imported and verified in keystore")
            } else {
                throw IllegalStateException("Key not found after import")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Key import failed", e)
            Log.e(TAG, "Exception: ${e.javaClass.name}: ${e.message}")
            // Don't generate a wrong key - just fail and let the caller handle it
            throw IllegalStateException(
                "Failed to import key using Secure Key Import: ${e.message}",
                e,
            )
        }
    }

    /** Parse private key from PEM format */
    private fun parsePrivateKeyFromPEM(pem: String): ByteArray {
        val pemContent =
            pem.replace("-----BEGIN EC PRIVATE KEY-----", "")
                .replace("-----BEGIN PRIVATE KEY-----", "")
                .replace("-----END EC PRIVATE KEY-----", "")
                .replace("-----END PRIVATE KEY-----", "")
                .replace("\\s".toRegex(), "")

        return Base64.decode(pemContent, Base64.NO_WRAP)
    }


    /**
     * Helper functions for getting app name and version
     */
    fun getAppVersionName(context: Context): String {

        var appVersionName = ""
        try {
            appVersionName =
                context.packageManager.getPackageInfo(context.packageName, 0).versionName?:""

        } catch (e: PackageManager.NameNotFoundException) {
            e.printStackTrace()
        }
        return appVersionName
    }

    fun getAppName(context: Context): String {
        var applicationInfo: ApplicationInfo? = null
        try {
            applicationInfo = context.packageManager.getApplicationInfo(context.applicationInfo.packageName, 0)
        } catch (e: PackageManager.NameNotFoundException) {
            Log.d("TAG", "The package with the given name cannot be found on the system.", e)
        }
        return (if (applicationInfo != null) context.packageManager.getApplicationLabel(applicationInfo) else "Unknown") as String

    }
}
