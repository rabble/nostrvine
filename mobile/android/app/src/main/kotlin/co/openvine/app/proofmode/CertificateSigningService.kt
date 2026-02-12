package co.openvine.app.proofmode

import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.BasicConstraints
import org.bouncycastle.asn1.x509.ExtendedKeyUsage
import org.bouncycastle.asn1.x509.Extension
import org.bouncycastle.asn1.x509.KeyPurposeId
import org.bouncycastle.asn1.x509.KeyUsage
import org.bouncycastle.asn1.x509.SubjectPublicKeyInfo
import org.bouncycastle.cert.X509v3CertificateBuilder
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509ExtensionUtils
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import org.bouncycastle.pkcs.PKCS10CertificationRequest
import org.bouncycastle.util.io.pem.PemObject
import org.bouncycastle.util.io.pem.PemReader
import org.bouncycastle.util.io.pem.PemWriter
import java.io.StringReader
import java.io.StringWriter
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.PrivateKey
import java.security.PublicKey
import java.security.Security
import java.security.cert.X509Certificate
import java.security.spec.ECGenParameterSpec
import java.security.spec.X509EncodedKeySpec
import java.util.Date
import java.util.UUID
import kotlin.time.ExperimentalTime
import kotlin.time.Instant

class CertificateSigningService {
    private val rootCA: X509Certificate
    private val rootCAPrivateKey: PrivateKey
    private val intermediateCA: X509Certificate
    private val intermediateCAPrivateKey: PrivateKey

    init {
        Security.addProvider(BouncyCastleProvider())

        // Generate Root CA
        val rootKeyPair = generateKeyPair()
        rootCAPrivateKey = rootKeyPair.private

        val rootSubject =
            X500Name(
                "CN=C2PA Test Root CA, O=C2PA Signing Server, OU=Certificate Authority, C=US, ST=California, L=San Francisco",
            )
        rootCA =
            generateCertificate(
                subject = rootSubject,
                issuer = rootSubject,
                publicKey = rootKeyPair.public,
                signerKey = rootCAPrivateKey,
                isCA = true,
                pathLenConstraint = 1,
                validityDays = 3650, // 10 years
            )

        // Generate Intermediate CA
        val intermediateKeyPair = generateKeyPair()
        intermediateCAPrivateKey = intermediateKeyPair.private

        val intermediateSubject =
            X500Name(
                "CN=C2PA Test Intermediate CA, O=C2PA Signing Server, OU=Certificate Authority, C=US, ST=California, L=San Francisco",
            )
        intermediateCA =
            generateCertificate(
                subject = intermediateSubject,
                issuer = X500Name(rootCA.subjectX500Principal.name),
                publicKey = intermediateKeyPair.public,
                signerKey = rootCAPrivateKey,
                isCA = true,
                pathLenConstraint = 0,
                validityDays = 1825, // 5 years
            )
    }

    @OptIn(ExperimentalTime::class)
    suspend fun signCSR(csrPEM: String): SignedCertificateSigningResponse {
        // Parse the CSR
        val csr = parseCertificateSigningRequest(csrPEM)

        // Extract public key and subject from CSR
        val publicKey = getPublicKeyFromCSR(csr)
        val subject = csr.subject

        // Generate end-entity certificate
        val certificate =
            generateCertificate(
                subject = subject,
                issuer = X500Name(intermediateCA.subjectX500Principal.name),
                publicKey = publicKey,
                signerKey = intermediateCAPrivateKey,
                isCA = false,
                pathLenConstraint = null,
                validityDays = 365, // 1 year
            )

        // Create certificate chain
        val certificateChain = buildString {
            append(certificateToPEM(certificate))
            append("\n")
            append(certificateToPEM(intermediateCA))
            append("\n")
            append(certificateToPEM(rootCA))
        }

        val certificateId = UUID.randomUUID().toString()
        val expiresAt = Instant.Companion.fromEpochMilliseconds(certificate.notAfter.time)

        return SignedCertificateSigningResponse(
            certificate_id = certificateId,
            certificate_chain = certificateChain,
            expires_at = expiresAt,
            serial_number = certificate.serialNumber.toString(),
        )
    }

    fun generateTemporaryCertificate(): Pair<String, PrivateKey> {
        val keyPair = generateKeyPair()

        val subject =
            X500Name(
                "CN=Temporary C2PA Signer, O=Temporary Certificate, OU=FOR TESTING ONLY, C=US",
            )
        val certificate =
            generateCertificate(
                subject = subject,
                issuer = X500Name(intermediateCA.subjectX500Principal.name),
                publicKey = keyPair.public,
                signerKey = intermediateCAPrivateKey,
                isCA = false,
                pathLenConstraint = null,
                validityDays = 1, // 1 day
            )

        val certificateChain = buildString {
            append(certificateToPEM(certificate))
            append("\n")
            append(certificateToPEM(intermediateCA))
            append("\n")
            append(certificateToPEM(rootCA))
        }

        return certificateChain to keyPair.private
    }

    private fun generateKeyPair(): KeyPair {
        val keyGen = KeyPairGenerator.getInstance("EC")
        keyGen.initialize(ECGenParameterSpec("secp256r1"))
        return keyGen.generateKeyPair()
    }

    private fun generateCertificate(
        subject: X500Name,
        issuer: X500Name,
        publicKey: PublicKey,
        signerKey: PrivateKey,
        isCA: Boolean,
        pathLenConstraint: Int?,
        validityDays: Int,
    ): X509Certificate {
        val now = Date()
        val notBefore = Date(now.time - 300000) // 5 minutes ago to avoid clock skew issues
        val notAfter = Date(now.time + validityDays * 24L * 60 * 60 * 1000)

        val serialNumber = BigInteger.valueOf(System.currentTimeMillis())

        val certBuilder =
            X509v3CertificateBuilder(
                issuer,
                serialNumber,
                notBefore,
                notAfter,
                subject,
                SubjectPublicKeyInfo.getInstance(publicKey.encoded),
            )

        // Add extensions
        val extUtils = JcaX509ExtensionUtils()

        // Subject Key Identifier
        certBuilder.addExtension(
            Extension.subjectKeyIdentifier,
            false,
            extUtils.createSubjectKeyIdentifier(publicKey),
        )

        // Authority Key Identifier (if not self-signed)
        if (issuer != subject) {
            certBuilder.addExtension(
                Extension.authorityKeyIdentifier,
                false,
                extUtils.createAuthorityKeyIdentifier(publicKey),
            )
        }

        // Basic Constraints
        certBuilder.addExtension(
            Extension.basicConstraints,
            true,
            if (pathLenConstraint != null) {
                BasicConstraints(pathLenConstraint)
            } else {
                BasicConstraints(false)
            },
        )

        // Key Usage
        val keyUsage =
            if (isCA) {
                KeyUsage(KeyUsage.keyCertSign or KeyUsage.cRLSign)
            } else {
                KeyUsage(KeyUsage.digitalSignature)
            }
        certBuilder.addExtension(
            Extension.keyUsage,
            true,
            keyUsage,
        )

        // Extended Key Usage for end-entity certificates
        if (!isCA) {
            val usages = listOf(KeyPurposeId.id_kp_emailProtection)
            certBuilder.addExtension(
                Extension.extendedKeyUsage,
                false,
                ExtendedKeyUsage(usages.toTypedArray()),
            )
        }

        val contentSigner =
            JcaContentSignerBuilder("SHA256withECDSA").build(signerKey)

        val certHolder = certBuilder.build(contentSigner)

        return JcaX509CertificateConverter().getCertificate(certHolder)
    }

    private fun parseCertificateSigningRequest(csrPEM: String): PKCS10CertificationRequest {
        val reader = PemReader(StringReader(csrPEM))
        val pemObject = reader.readPemObject()
        reader.close()

        require(pemObject.type == "CERTIFICATE REQUEST") { "Invalid CSR format" }

        return PKCS10CertificationRequest(pemObject.content)
    }

    private fun getPublicKeyFromCSR(csr: PKCS10CertificationRequest): PublicKey {
        val keyFactory = KeyFactory.getInstance("EC")
        val keySpec =
            X509EncodedKeySpec(
                csr.subjectPublicKeyInfo.encoded,
            )
        return keyFactory.generatePublic(keySpec)
    }

    private fun certificateToPEM(certificate: X509Certificate): String {
        val writer = StringWriter()
        val pemWriter = PemWriter(writer)
        pemWriter.writeObject(PemObject("CERTIFICATE", certificate.encoded))
        pemWriter.close()
        return writer.toString()
    }
}


data class SignedCertificateSigningResponse @OptIn(ExperimentalTime::class) constructor(
    val certificate_id: String,
    val certificate_chain: String, // PEM-encoded certificate chain
    val expires_at: Instant,
    val serial_number: String,
)
