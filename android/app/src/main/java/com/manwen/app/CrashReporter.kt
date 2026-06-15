package com.manwen.app

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Catches every uncaught JVM exception in the app, formats a full crash report
 * (device info + stack trace), and writes it to FOUR locations so it is
 * discoverable from the phone without adb:
 *
 *   1. /sdcard/Android/data/com.manwen.app/files/crash.log
 *      (primary; most file managers can reach this with scoped-storage support)
 *
 *   2. /data/data/com.manwen.app/cache/crash.log
 *      (internal cache — adb-pullable as `adb shell run-as com.manwen.app
 *      cat cache/crash.log`; never subject to external storage weirdness)
 *
 *   3. /sdcard/Download/ManWen-crash-<timestamp>.log
 *      (MediaStore Downloads on API 29+ — shows up in the system Downloads
 *      app, the most discoverable location on modern Android)
 *
 *   4. Marker file at /sdcard/Android/data/com.manwen.app/files/.last_crash_present
 *      read by MainActivity.onCreate to show a Toast on the NEXT launch
 *      pointing the user to the log file
 *
 * Plus the previous UncaughtExceptionHandler is still chained so the
 * stock "App has stopped" dialog still appears (we don't suppress the OS
 * UX — we just augment it with a discoverable log).
 */
object CrashReporter {
    private const val TAG = "ManWenCrash"
    private const val FILE_NAME = "crash.log"
    private const val MARKER_NAME = ".last_crash_present"
    private val TS_FILE = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
    private val TS_HUMAN = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US)

    fun install(context: Context) {
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val now = System.currentTimeMillis()
                val crashText = buildString {
                    appendLine("=== Man Wen Crash at ${TS_HUMAN.format(Date(now))} ===")
                    appendLine("Thread: ${thread.name}")
                    runCatching {
                        val info = app.packageManager.getPackageInfo(app.packageName, 0)
                        appendLine("App version: ${info.versionName} (code ${info.longVersionCode})")
                    }
                    appendLine("Android: ${Build.VERSION.RELEASE} (SDK ${Build.VERSION.SDK_INT})")
                    appendLine("Device: ${Build.MANUFACTURER} ${Build.MODEL}")
                    appendLine("ABI: ${Build.SUPPORTED_ABIS.joinToString()}")
                    appendLine()
                    val sw = StringWriter()
                    throwable.printStackTrace(PrintWriter(sw))
                    append(sw.toString())
                }

                // 1. External app-private files dir
                runCatching {
                    val extFile = File(app.getExternalFilesDir(null), FILE_NAME)
                    extFile.writeText(crashText)
                    Log.e(TAG, "Wrote crash to ${extFile.absolutePath}")
                }.onFailure { Log.e(TAG, "Failed ext crash write", it) }

                // 2. Internal cache (always writable, never scoped-storage-restricted)
                runCatching {
                    val cacheFile = File(app.cacheDir, FILE_NAME)
                    cacheFile.writeText(crashText)
                    Log.e(TAG, "Wrote crash to ${cacheFile.absolutePath}")
                }.onFailure { Log.e(TAG, "Failed cache crash write", it) }

                // 3. MediaStore Downloads on Android 10+ — shows in the Downloads app
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    runCatching { writeToMediaStore(app, crashText, TS_FILE.format(Date(now))) }
                        .onFailure { Log.e(TAG, "Failed MediaStore crash write", it) }
                }

                // 4. Marker for MainActivity to surface on the next launch
                runCatching {
                    val marker = File(app.getExternalFilesDir(null), MARKER_NAME)
                    marker.writeText(TS_HUMAN.format(Date(now)))
                }

                Log.e(TAG, crashText)
            } catch (loggingFailure: Throwable) {
                Log.e(TAG, "Failed to persist crash log", loggingFailure)
            }
            previous?.uncaughtException(thread, throwable)
        }
    }

    /**
     * If a crash happened on the previous run, return the timestamp string
     * and clear the marker. Returns null if no crash marker was present.
     * MainActivity calls this from onCreate to show a Toast pointing the user
     * to the saved crash log.
     */
    fun consumePreviousCrashMarker(context: Context): String? {
        return try {
            val marker = File(context.getExternalFilesDir(null), MARKER_NAME)
            if (marker.exists()) {
                val ts = marker.readText().trim()
                marker.delete()
                ts
            } else null
        } catch (_: Throwable) {
            null
        }
    }

    /** Human-readable paths the user can look for in a file manager. */
    fun describeLocations(context: Context): String {
        val ext = context.getExternalFilesDir(null)?.absolutePath
            ?: "(unavailable)"
        val cache = context.cacheDir.absolutePath
        val downloads = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            "Downloads/ManWen-crash-<timestamp>.log (visible in the Downloads app)"
        else "n/a (requires Android 10+ for public Downloads)"
        return "App-private: $ext/crash.log\n" +
                "Internal cache: $cache/crash.log\n" +
                "Public Downloads: $downloads"
    }

    private fun writeToMediaStore(context: Context, text: String, ts: String) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, "ManWen-crash-$ts.log")
            put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
        }
        val resolver = context.contentResolver
        val uri: Uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore.insert returned null")
        resolver.openOutputStream(uri)?.use { out ->
            out.write(text.toByteArray(Charsets.UTF_8))
        } ?: throw IllegalStateException("openOutputStream returned null")
        Log.i(TAG, "Wrote crash to MediaStore Downloads: $uri")
    }
}
