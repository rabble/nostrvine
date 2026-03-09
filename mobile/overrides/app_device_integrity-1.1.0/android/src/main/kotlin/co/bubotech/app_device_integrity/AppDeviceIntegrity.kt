package co.bubotech.app_device_integrity

import android.content.Context
import com.google.android.gms.tasks.Task
import com.google.android.play.core.integrity.IntegrityManager
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenResponse
import com.google.android.play.core.integrity.IntegrityTokenRequest
import java.security.MessageDigest

class AppDeviceIntegrity(
    context: Context,
    challengeString: String,
    cloudProjectNumber: Long,
) {

    val nonce: String = createNonce(challengeString)

    // Create an instance of a manager.
    val integrityManager: IntegrityManager = IntegrityManagerFactory.create(context)

    // Request the integrity token by providing a nonce.
    val integrityTokenResponse: Task<IntegrityTokenResponse> = integrityManager.requestIntegrityToken(
        IntegrityTokenRequest.builder()
            .setNonce(nonce)
            .setCloudProjectNumber(cloudProjectNumber)
            .build())

    companion object {
        fun createNonce(challengeString: String): String {
            val digest = MessageDigest
                .getInstance("SHA-256")
                .digest(challengeString.toByteArray(Charsets.UTF_8))

            // Play Integrity classic requests require a Base64 web-safe no-wrap nonce.
            return encodeBase64UrlNoPadding(digest)
        }

        private fun encodeBase64UrlNoPadding(bytes: ByteArray): String {
            val alphabet =
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
            val output = StringBuilder(((bytes.size + 2) / 3) * 4)
            var index = 0

            while (index < bytes.size) {
                val byte0 = bytes[index].toInt() and 0xFF
                val byte1 =
                    if (index + 1 < bytes.size) {
                        bytes[index + 1].toInt() and 0xFF
                    } else {
                        -1
                    }
                val byte2 =
                    if (index + 2 < bytes.size) {
                        bytes[index + 2].toInt() and 0xFF
                    } else {
                        -1
                    }

                output.append(alphabet[byte0 ushr 2])
                output.append(alphabet[((byte0 and 0x03) shl 4) or if (byte1 >= 0) byte1 ushr 4 else 0])

                if (byte1 >= 0) {
                    output.append(alphabet[((byte1 and 0x0F) shl 2) or if (byte2 >= 0) byte2 ushr 6 else 0])
                }

                if (byte2 >= 0) {
                    output.append(alphabet[byte2 and 0x3F])
                }

                index += 3
            }

            return output.toString()
        }
    }
}
