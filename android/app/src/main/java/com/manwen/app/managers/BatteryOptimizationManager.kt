package com.manwen.app.managers

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

class BatteryOptimizationManager(private val context: Context) {

    companion object {
        const val TAG = "BatteryOpt"
    }

    fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun requestBatteryOptimizationExemption(activity: Activity) {
        if (!isIgnoringBatteryOptimizations()) {
            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
            }
            activity.startActivity(intent)
        }
    }

    fun getFrameSamplingInterval(batteryLevel: Int): Long {
        return when {
            batteryLevel > 80 -> 500L
            batteryLevel > 50 -> 1000L
            batteryLevel > 20 -> 2000L
            else -> 5000L
        }
    }
}