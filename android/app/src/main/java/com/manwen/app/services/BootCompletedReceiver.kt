package com.manwen.app.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootCompletedReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (Intent.ACTION_BOOT_COMPLETED == intent.action) {
            Log.i(TAG, "Boot completed — restarting site blocker if enabled")
            // Check if site blocker was enabled before reboot
            val prefs = context.getSharedPreferences("manwen_prefs", Context.MODE_PRIVATE)
            if (prefs.getBoolean("site_blocker_enabled", false)) {
                val serviceIntent = Intent(context, SiteBlockerService::class.java).apply {
                    action = SiteBlockerService.ACTION_START
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            }
        }
    }
}