package com.unity_kit

import android.content.Context
import android.os.Build
import android.system.Os
import android.system.OsConstants
import android.util.Log
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder

/// Inspects what Unity runtime the host app actually ships, and whether its
/// native libraries satisfy Google Play's 16 KB page size requirement.
///
/// Both answers are read from the running app rather than assumed from a
/// Unity version number: an app can be built with a compliant Unity and
/// still ship an old prebuilt `.so`, and the failure only shows up at
/// upload time or on a 16 KB device.
internal object UnityEnvironmentProbe {

    private const val TAG = "UnityEnvironmentProbe"

    private const val UNITY_6_CLASS = "com.unity3d.player.UnityPlayerForActivityOrService"
    private const val UNITY_LEGACY_CLASS = "com.unity3d.player.UnityPlayer"

    /// Minimum segment alignment Google Play requires for apps targeting
    /// Android 15 (API 35) and above.
    private const val REQUIRED_ALIGNMENT = 16 * 1024L

    /// Libraries reported first, because they are the ones Unity ships.
    private val UNITY_LIBRARY_NAMES = listOf("libunity.so", "libil2cpp.so", "libmain.so")

    /// Builds the report handed to Dart.
    fun probe(context: Context): Map<String, Any?> {
        val (runtime, playerClass) = detectRuntime()
        val libraries = inspectNativeLibraries(context)

        return mapOf(
            "runtime" to runtime,
            "playerClassName" to playerClass,
            "pageAlignment" to worstAlignment(libraries),
            "devicePageSizeBytes" to devicePageSize(),
            "abi" to Build.SUPPORTED_ABIS.firstOrNull(),
            "platformVersion" to Build.VERSION.RELEASE,
            "libraries" to libraries,
        )
    }

    /// Resolves which player class this build carries.
    ///
    /// Mirrors the order [UnityPlayerManager] tries them in, so the report
    /// names the class that would actually be instantiated.
    private fun detectRuntime(): Pair<String, String?> {
        if (classExists(UNITY_6_CLASS)) return "unity6" to UNITY_6_CLASS
        if (classExists(UNITY_LEGACY_CLASS)) return "legacy" to UNITY_LEGACY_CLASS
        return "absent" to null
    }

    private fun classExists(name: String): Boolean {
        return try {
            Class.forName(name, false, UnityEnvironmentProbe::class.java.classLoader)
            true
        } catch (_: ClassNotFoundException) {
            false
        } catch (t: Throwable) {
            // A class that exists but fails to resolve still counts as present.
            Log.d(TAG, "Class $name resolved with ${t.javaClass.simpleName}")
            true
        }
    }

    /// Page size the kernel runs with, or 0 when it cannot be read.
    private fun devicePageSize(): Int {
        return try {
            Os.sysconf(OsConstants._SC_PAGESIZE).toInt()
        } catch (t: Throwable) {
            Log.d(TAG, "Page size unavailable: ${t.message}")
            0
        }
    }

    /// Reads the segment alignment of every extracted native library,
    /// Unity's own first.
    private fun inspectNativeLibraries(context: Context): List<Map<String, Any?>> {
        val dir = context.applicationInfo.nativeLibraryDir
        if (dir.isNullOrEmpty()) return emptyList()

        val files = File(dir).listFiles { file -> file.name.endsWith(".so") }
            ?.sortedBy { file ->
                // Unity's libraries first; they are what an upgrade breaks.
                val index = UNITY_LIBRARY_NAMES.indexOf(file.name)
                if (index >= 0) index else UNITY_LIBRARY_NAMES.size
            }
            ?: return emptyList()

        return files.map { file ->
            val alignment = readMinimumLoadAlignment(file)
            mapOf(
                "name" to file.name,
                "alignmentBytes" to (alignment ?: 0L),
                "alignment" to when {
                    alignment == null -> "unknown"
                    alignment >= REQUIRED_ALIGNMENT -> "aligned"
                    else -> "unaligned"
                },
            )
        }
    }

    /// Worst status across all inspected libraries.
    ///
    /// One unaligned library is enough to fail the requirement, so that wins
    /// over any number of aligned ones.
    private fun worstAlignment(libraries: List<Map<String, Any?>>): String {
        if (libraries.isEmpty()) return "unknown"
        if (libraries.any { it["alignment"] == "unaligned" }) return "unaligned"
        if (libraries.all { it["alignment"] == "aligned" }) return "aligned"
        return "unknown"
    }

    /// Returns the smallest `p_align` across the PT_LOAD program headers of
    /// an ELF file, or null when the file cannot be parsed.
    ///
    /// That value is what the loader has to honour, so it is what decides
    /// whether the library runs on a 16 KB kernel.
    private fun readMinimumLoadAlignment(file: File): Long? {
        return try {
            RandomAccessFile(file, "r").use { raf -> parseElfLoadAlignment(raf) }
        } catch (t: Throwable) {
            Log.d(TAG, "Could not read ${file.name}: ${t.message}")
            null
        }
    }

    private const val ELF_HEADER_SIZE = 64
    private const val PT_LOAD = 1

    private fun parseElfLoadAlignment(raf: RandomAccessFile): Long? {
        val header = ByteArray(ELF_HEADER_SIZE)
        if (raf.read(header) < ELF_HEADER_SIZE) return null

        // Magic: 0x7F 'E' 'L' 'F'
        if (header[0] != 0x7F.toByte() ||
            header[1] != 'E'.code.toByte() ||
            header[2] != 'L'.code.toByte() ||
            header[3] != 'F'.code.toByte()
        ) {
            return null
        }

        val is64Bit = header[4].toInt() == 2 // EI_CLASS: 2 = ELFCLASS64
        val isLittleEndian = header[5].toInt() == 1 // EI_DATA: 1 = LSB
        val order = if (isLittleEndian) ByteOrder.LITTLE_ENDIAN else ByteOrder.BIG_ENDIAN
        val buffer = ByteBuffer.wrap(header).order(order)

        // Program header table offset, entry size and count. 32-bit and
        // 64-bit ELF put them at different offsets.
        val phOffset: Long
        val phEntrySize: Int
        val phCount: Int
        if (is64Bit) {
            phOffset = buffer.getLong(32)
            phEntrySize = buffer.getShort(54).toInt() and 0xFFFF
            phCount = buffer.getShort(56).toInt() and 0xFFFF
        } else {
            phOffset = buffer.getInt(28).toLong() and 0xFFFFFFFFL
            phEntrySize = buffer.getShort(42).toInt() and 0xFFFF
            phCount = buffer.getShort(44).toInt() and 0xFFFF
        }
        if (phCount == 0 || phEntrySize == 0) return null

        var smallest: Long? = null
        val entry = ByteArray(phEntrySize)
        for (index in 0 until phCount) {
            raf.seek(phOffset + index.toLong() * phEntrySize)
            if (raf.read(entry) < phEntrySize) break
            val entryBuffer = ByteBuffer.wrap(entry).order(order)

            val type = entryBuffer.getInt(0)
            if (type != PT_LOAD) continue

            // p_align is the last field of the program header.
            val align = if (is64Bit) {
                if (phEntrySize < 56) continue
                entryBuffer.getLong(48)
            } else {
                if (phEntrySize < 32) continue
                entryBuffer.getInt(28).toLong() and 0xFFFFFFFFL
            }
            if (align <= 0) continue
            if (smallest == null || align < smallest) smallest = align
        }
        return smallest
    }
}
