package com.manwen.app.data.preferences

import androidx.datastore.preferences.core.*

object AppPreferencesKeys {
    val BLOCKING_SENSITIVITY = floatPreferencesKey("blocking_sensitivity")
    val DANGER_HOURS_START = intPreferencesKey("danger_hours_start")
    val DANGER_HOURS_END = intPreferencesKey("danger_hours_end")
    val ACCOUNTABILITY_MODE = booleanPreferencesKey("accountability_mode")
    val APP_LAUNCH_COUNT = intPreferencesKey("app_launch_count")
    val FIRST_LAUNCH_DATE = longPreferencesKey("first_launch_date")
    val ONBOARDING_COMPLETE = booleanPreferencesKey("onboarding_complete")
    val IS_PREMIUM = booleanPreferencesKey("is_premium")
    val PREMIUM_EXPIRY = longPreferencesKey("premium_expiry")
}