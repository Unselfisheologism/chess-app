package com.manwen.app.data.local.daos

import androidx.room.*
import com.manwen.app.data.local.entities.LocalAnalyticsEvent
import kotlinx.coroutines.flow.Flow

@Dao
interface UrgeSurfingDao {
    @Query("SELECT * FROM urge_surfing_sessions ORDER BY startTime DESC LIMIT 50")
    fun getRecentSessions(): Flow<List<com.manwen.app.data.local.entities.UrgeSurfingSession>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: com.manwen.app.data.local.entities.UrgeSurfingSession)

    @Query("UPDATE urge_surfing_sessions SET endTime = :endTime, finalUrgeLevel = :finalLevel, wasSuccessful = :success WHERE id = :id")
    suspend fun completeSession(id: String, endTime: Long, finalLevel: Int, success: Boolean)
}

@Dao
interface ManagedAppsDao {
    @Query("SELECT * FROM managed_apps WHERE isWhitelisted = 1")
    fun getWhitelist(): Flow<List<com.manwen.app.data.local.entities.ManagedApp>>

    @Query("SELECT * FROM managed_apps WHERE isWhitelisted = 0")
    fun getBlacklist(): Flow<List<com.manwen.app.data.local.entities.ManagedApp>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertApp(app: com.manwen.app.data.local.entities.ManagedApp)

    @Query("DELETE FROM managed_apps WHERE packageName = :packageName")
    suspend fun deleteApp(packageName: String)

    @Query("SELECT COUNT(*) FROM managed_apps")
    suspend fun getManagedCount(): Int
}

@Dao
interface AnalyticsDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertEvent(event: LocalAnalyticsEvent)

    @Query("SELECT * FROM analytics_events ORDER BY timestamp DESC LIMIT 500")
    fun getRecentEvents(): Flow<List<LocalAnalyticsEvent>>

    @Query("DELETE FROM analytics_events WHERE timestamp < :cutoff")
    suspend fun deleteOlderThan(cutoff: Long)

    @Query("SELECT COUNT(*) FROM analytics_events")
    suspend fun getEventCount(): Int

    @Query("SELECT * FROM analytics_events")
    suspend fun getAllEvents(): List<LocalAnalyticsEvent>
}
