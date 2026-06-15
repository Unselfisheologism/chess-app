package com.manwen.app

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.util.Log
import com.manwen.app.data.local.AppDatabase
import com.manwen.app.data.preferences.PreferencesManager

class ManWenApplication : Application() {

    // Lazy so the (potentially heavy) Room + DataStore init does not run on the
    // main thread during Application.onCreate(). A failure in either will surface
    // on first access instead of killing the app before any UI shows.
    val database: AppDatabase by lazy {
        AppDatabase.getInstance(this)
    }

    val preferences: PreferencesManager by lazy {
        PreferencesManager(this)
    }

    override fun onCreate() {
        super.onCreate()
        try {
            CrashReporter.install(this)
        } catch (t: Throwable) {
            // Crash handler is best-effort — never let it block app start.
            Log.e("ManWenApp", "CrashReporter.install failed", t)
        }
        try {
            createNotificationChannels()
        } catch (t: Throwable) {
            Log.e("ManWenApp", "createNotificationChannels failed", t)
        }
        // `database` and `preferences` are intentionally NOT touched here —
        // they're lazy and will initialize on first access from a screen.
    }

    // installCrashHandler moved into CrashReporter.install() — keeps
    // the full report (device info + stack trace) in 4 discoverable locations
    // including the public Downloads directory on Android 10+.

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channels = listOf(
                NotificationChannel(
                    "site_blocker_channel",
                    "Site Blocker",
                    NotificationManager.IMPORTANCE_LOW
                ),
                NotificationChannel(
                    "urge_surfing_channel",
                    "Urge Surfing",
                    NotificationManager.IMPORTANCE_DEFAULT
                ),
                NotificationChannel(
                    "accountability_channel",
                    "Accountability Partner",
                    NotificationManager.IMPORTANCE_DEFAULT
                )
            )
            getSystemService(NotificationManager::class.java).createNotificationChannels(channels)
        }
    }
}
