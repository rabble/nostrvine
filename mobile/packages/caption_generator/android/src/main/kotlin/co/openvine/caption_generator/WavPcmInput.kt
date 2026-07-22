// ABOUTME: Minimal RIFF/WAVE reader for the recognizer input on Android.
// ABOUTME: Validates 16-bit mono PCM and exposes the raw data-chunk region.

package co.openvine.caption_generator

import java.io.File
import java.io.IOException
import java.io.RandomAccessFile

/**
 * The PCM payload of a WAV file, located so it can be streamed to Vosk.
 *
 * The Dart layer converts arbitrary extracted audio to 16 kHz mono 16-bit
 * PCM before invoking the platform, so this reader only needs to validate
 * that contract and find the data chunk — it never converts.
 */
internal class WavPcmInput(
    val file: File,
    val sampleRate: Int,
    val dataOffset: Long,
    val dataLength: Long,
) {
    companion object {
        private const val PCM_FORMAT = 1
        private const val EXPECTED_CHANNELS = 1
        private const val EXPECTED_BITS_PER_SAMPLE = 16

        /**
         * Parses [file] and validates it is 16-bit mono integer PCM.
         *
         * @throws TranscriptionException with code `invalid_audio` when the
         *   file is not a WAV in the expected encoding.
         */
        @Throws(TranscriptionException::class)
        fun parse(file: File): WavPcmInput {
            try {
                RandomAccessFile(file, "r").use { raf ->
                    val fileLength = raf.length()
                    val riff = ByteArray(12)
                    if (fileLength < 12) invalid("File too short to be a WAV")
                    raf.readFully(riff)
                    if (!riff.hasTag(0, "RIFF") || !riff.hasTag(8, "WAVE")) {
                        // Distinct from the Dart parser's wording so logs show
                        // which layer rejected the file.
                        invalid("Recognizer input is not a RIFF/WAVE file")
                    }
                    var formatCode = -1
                    var channels = -1
                    var sampleRate = -1
                    var bitsPerSample = -1
                    var dataOffset = -1L
                    var dataLength = -1L
                    var offset = 12L
                    val header = ByteArray(8)
                    while (offset + 8 <= fileLength) {
                        raf.seek(offset)
                        raf.readFully(header)
                        val chunkSize = header.uint32At(4)
                        val bodyOffset = offset + 8
                        if (header.hasTag(0, "fmt ") && chunkSize >= 16) {
                            val fmt = ByteArray(16)
                            raf.readFully(fmt)
                            formatCode = fmt.uint16At(0)
                            channels = fmt.uint16At(2)
                            sampleRate = fmt.uint32At(4).toInt()
                            bitsPerSample = fmt.uint16At(14)
                        } else if (header.hasTag(0, "data")) {
                            dataOffset = bodyOffset
                            dataLength = minOf(chunkSize, fileLength - bodyOffset)
                        }
                        // Chunks are word-aligned; odd sizes carry a pad byte.
                        offset = bodyOffset + chunkSize + (chunkSize % 2)
                    }
                    if (formatCode == -1) invalid("WAV has no fmt chunk")
                    if (dataOffset == -1L) invalid("WAV has no data chunk")
                    if (formatCode != PCM_FORMAT ||
                        channels != EXPECTED_CHANNELS ||
                        bitsPerSample != EXPECTED_BITS_PER_SAMPLE ||
                        sampleRate < 1
                    ) {
                        invalid(
                            "Expected 16-bit mono PCM, got format $formatCode, " +
                                "$channels channel(s), $bitsPerSample bits at " +
                                "$sampleRate Hz",
                        )
                    }
                    return WavPcmInput(file, sampleRate, dataOffset, dataLength)
                }
            } catch (e: IOException) {
                throw TranscriptionException(
                    "invalid_audio",
                    "Failed to read WAV file: ${e.message}",
                )
            }
        }

        private fun invalid(message: String): Nothing =
            throw TranscriptionException("invalid_audio", message)

        private fun ByteArray.hasTag(offset: Int, tag: String): Boolean =
            tag.withIndex().all { (i, c) -> this[offset + i] == c.code.toByte() }

        private fun ByteArray.uint16At(offset: Int): Int =
            (this[offset].toInt() and 0xFF) or
                ((this[offset + 1].toInt() and 0xFF) shl 8)

        private fun ByteArray.uint32At(offset: Int): Long =
            (this[offset].toLong() and 0xFF) or
                ((this[offset + 1].toLong() and 0xFF) shl 8) or
                ((this[offset + 2].toLong() and 0xFF) shl 16) or
                ((this[offset + 3].toLong() and 0xFF) shl 24)
    }
}

/** A transcription failure carrying the platform channel error [code]. */
internal class TranscriptionException(
    val code: String,
    message: String,
) : Exception(message)
