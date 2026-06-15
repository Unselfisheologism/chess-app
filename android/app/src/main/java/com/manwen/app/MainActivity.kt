package com.manwen.app

import android.content.Context
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.manwen.app.services.SiteBlockerService
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val channel = "com.manwen.app/manwen"
    private val errorChannel = "com.manwen.app/dart_errors"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Show a Toast if the previous launch crashed, pointing the user at
        // the saved crash log. consumePreviousCrashMarker deletes the marker
        // file so the Toast only shows ONCE per crash, not on every launch.
        runCatching {
            val previousCrash = CrashReporter.consumePreviousCrashMarker(this)
            if (previousCrash != null) {
                val desc = CrashReporter.describeLocations(this)
                Log.e("ManWenMain", "Previous crash at $previousCrash\n$desc")
                Toast.makeText(
                    this,
                    "Man Wen crashed at $previousCrash. Check Downloads for ManWen-crash-*.log",
                    Toast.LENGTH_LONG
                ).show()
            }
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register the local SharedPreferencesPlugin. The pubspec
        // pins shared_preferences to 2.2.x (Dart 3.4 compatible), but
        // the Flutter Gradle plugin's auto-generated registrant
        // doesn't compile the local
        // android/app/src/main/java/io/flutter/plugins/sharedpreferences/
        // SharedPreferencesPlugin.java into the release APK under this
        // project setup. Registering it explicitly here bypasses that
        // gap. Without this, every SharedPreferences call from Dart
        // throws 'PlatformException(channel-error, Unable to
        // establish connection on channel.)' — which manifests as
        // 'Failed to load stats' on the StatsScreen and a silent
        // always-zero streak on the home screen.
        flutterEngine.plugins.add(SharedPreferencesPlugin())

        // Existing platform channel for site blocker / paywall
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSiteBlocking" -> {
                    SiteBlockerService.start(this as Context)
                    result.success(true)
                }
                "stopSiteBlocking" -> {
                    SiteBlockerService.stop(this as Context)
                    result.success(true)
                }
                "openPaywall" -> {
                    // Keep legacy paywall
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Dart error reporting channel. Dart-level errors (widget build
        // failures, uncaught async exceptions, PlatformDispatcher errors)
        // don't reach the JVM uncaught-exception handler, so without this
        // they only show in logcat. Forward them to CrashReporter so they
        // land in the same /sdcard/Download/ManWen-dart-errors.log file
        // that's easy to retrieve from the phone.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, errorChannel).setMethodCallHandler { call, result ->
            if (call.method == "reportError") {
                val title = call.argument<String>("title") ?: "Dart error"
                val message = call.argument<String>("message") ?: "(no message)"
                val stack = call.argument<String>("stack") ?: "(no stack)"
                writeDartError(title, message, stack)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun writeDartError(title: String, message: String, stack: String) {
        try {
            val ts = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            val text = "=== $title at $ts ===\n$message\n$stack\n\n"

            // 1. External files dir (mirrors CrashReporter)
            runCatching {
                val extFile = File(getExternalFilesDir(null), "dart_errors.log")
                extFile.appendText(text)
            }

            // 2. MediaStore Downloads on API 29+ so it shows in the system
            //    Downloads app, same way the JVM CrashReporter does.
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                runCatching {
                    val values = android.content.ContentValues().apply {
                        put(
                            android.provider.MediaStore.MediaColumns.DISPLAY_NAME,
                            "ManWen-dart-errors.log"
                        )
                        put(
                            android.provider.MediaStore.MediaColumns.MIME_TYPE,
                            "text/plain"
                        )
                        put(
                            android.provider.MediaStore.MediaColumns.RELATIVE_PATH,
                            android.os.Environment.DIRECTORY_DOWNLOADS
                        )
                    }
                    val resolver = contentResolver
                    val uri = resolver.insert(
                        android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                        values
                    )
                    uri?.let { u ->
                        resolver.openOutputStream(u, "wa")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
                    }
                }
            }

            // 3. Also log to logcat (useful if user does eventually get adb)
            Log.e("ManWenDart", "$title: $message", RuntimeException(stack))
        } catch (loggingFailure: Throwable) {
            Log.e("ManWenDart", "Failed to persist dart error", loggingFailure)
        }
    }
}
