package com.manwen.app.data.local.entities

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.*

@Entity(tableName = "user_progress")
data class UserProgress(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val startDate: Long = System.currentTimeMillis(),
    val lastRelapseDate: Long? = null,
    val totalRelapses: Int = 0,
    val nsfwBlocksCount: Int = 0,
    val urgeSurfingSessions: Int = 0,
    val isPremium: Boolean = false,
    val premiumExpiryDate: Long? = null
)

@Entity(tableName = "daily_checkins")
data class DailyCheckIn(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long, // UTC midnight timestamp
    val mood: Int, // 1-10 scale
    val urgeLevel: Int, // 1-10 scale
    val notes: String? = null,
    val completed: Boolean = false
)

@Entity(tableName = "urge_surfing_sessions")
data class UrgeSurfingSession(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val startTime: Long,
    val endTime: Long? = null,
    val initialUrgeLevel: Int,
    val finalUrgeLevel: Int? = null,
    val techniquesUsed: List<String> = emptyList(),
    val wasSuccessful: Boolean? = null
)

@Entity(tableName = "managed_apps")
data class ManagedApp(
    @PrimaryKey val packageName: String,
    val appName: String,
    val isWhitelisted: Boolean,
    val addedDate: Long,
    val isSystemApp: Boolean = false
)

@Entity(tableName = "analytics_events")
data class LocalAnalyticsEvent(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val timestamp: Long,
    val eventName: String,
    val propertiesJson: String
)
