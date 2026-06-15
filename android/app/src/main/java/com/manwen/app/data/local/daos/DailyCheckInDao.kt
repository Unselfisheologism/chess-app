package com.manwen.app.data.local.daos

import androidx.room.*
import com.manwen.app.data.local.entities.DailyCheckIn
import kotlinx.coroutines.flow.Flow

@Dao
interface DailyCheckInDao {
    @Query("SELECT * FROM daily_checkins ORDER BY date DESC LIMIT 30")
    fun getRecentCheckIns(): Flow<List<DailyCheckIn>>

    @Query("SELECT * FROM daily_checkins WHERE date = :date LIMIT 1")
    suspend fun getCheckInForDate(date: Long): DailyCheckIn?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertCheckIn(checkIn: DailyCheckIn)

    @Query("DELETE FROM daily_checkins WHERE date < :cutoffTimestamp")
    suspend fun deleteOlderThan(cutoffTimestamp: Long)
}
