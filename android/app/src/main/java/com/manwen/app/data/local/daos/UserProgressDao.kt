package com.manwen.app.data.local.daos

import androidx.room.*
import com.manwen.app.data.local.entities.*
import kotlinx.coroutines.flow.Flow

@Dao
interface UserProgressDao {
    @Query("SELECT * FROM user_progress LIMIT 1")
    fun getProgress(): Flow<UserProgress?>

    @Query("SELECT * FROM user_progress LIMIT 1")
    suspend fun getProgressOnce(): UserProgress?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertProgress(progress: UserProgress)

    @Query("UPDATE user_progress SET currentStreak = :streak, lastRelapseDate = :relapseDate WHERE id = :id")
    suspend fun updateStreak(id: String, streak: Int, relapseDate: Long?)

    @Query("UPDATE user_progress SET currentStreak = currentStreak + 1 WHERE id = :id")
    suspend fun incrementStreak(id: String)

    @Query("UPDATE user_progress SET totalRelapses = totalRelapses + 1, currentStreak = 0, lastRelapseDate = :relapseDate WHERE id = :id")
    suspend fun recordRelapse(id: String, relapseDate: Long = System.currentTimeMillis())

    @Query("UPDATE user_progress SET urgeSurfingSessions = urgeSurfingSessions + 1 WHERE id = :id")
    suspend fun incrementUrgeSurfingSessions(id: String)

    @Query("UPDATE user_progress SET isPremium = :isPremium, premiumExpiryDate = :expiry WHERE id = :id")
    suspend fun updatePremiumStatus(id: String, isPremium: Boolean, expiry: Long?)
}
