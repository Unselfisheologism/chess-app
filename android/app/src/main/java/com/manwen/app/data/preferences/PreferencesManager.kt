package com.manwen.app.data.preferences

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.*
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "man_wen_prefs")

class PreferencesManager(private val context: Context) {

    val blockingSensitivity: Flow<Float> = context.dataStore.data
        .map { it[AppPreferencesKeys.BLOCKING_SENSITIVITY] ?: 0.75f }

    val dangerHoursStart: Flow<Int> = context.dataStore.data
        .map { it[AppPreferencesKeys.DANGER_HOURS_START] ?: 22 }

    val dangerHoursEnd: Flow<Int> = context.dataStore.data
        .map { it[AppPreferencesKeys.DANGER_HOURS_END] ?: 6 }

    val isPremium: Flow<Boolean> = context.dataStore.data
        .map { it[AppPreferencesKeys.IS_PREMIUM] ?: false }

    val onboardingComplete: Flow<Boolean> = context.dataStore.data
        .map { it[AppPreferencesKeys.ONBOARDING_COMPLETE] ?: false }

    suspend fun setBlockingSensitivity(sensitivity: Float) {
        context.dataStore.edit { it[AppPreferencesKeys.BLOCKING_SENSITIVITY] = sensitivity }
    }

    suspend fun setDangerHours(start: Int, end: Int) {
        context.dataStore.edit {
            it[AppPreferencesKeys.DANGER_HOURS_START] = start
            it[AppPreferencesKeys.DANGER_HOURS_END] = end
        }
    }

    suspend fun setPremiumStatus(isPremium: Boolean, expiry: Long? = null) {
        context.dataStore.edit {
            it[AppPreferencesKeys.IS_PREMIUM] = isPremium
            it[AppPreferencesKeys.PREMIUM_EXPIRY] = expiry ?: 0L
        }
    }

    suspend fun completeOnboarding() {
        context.dataStore.edit { it[AppPreferencesKeys.ONBOARDING_COMPLETE] = true }
    }
}