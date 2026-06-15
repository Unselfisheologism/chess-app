package com.manwen.app.data.local

import android.content.Context
import androidx.room.*
import com.manwen.app.data.local.entities.UserProgress
import com.manwen.app.data.local.entities.DailyCheckIn
import com.manwen.app.data.local.entities.UrgeSurfingSession
import com.manwen.app.data.local.entities.ManagedApp
import com.manwen.app.data.local.entities.LocalAnalyticsEvent
import org.json.JSONArray

class Converters {
    @TypeConverter
    fun fromStringList(value: List<String>): String = JSONArray(value).toString()

    @TypeConverter
    fun toStringList(value: String): List<String> {
        if (value.isBlank()) return emptyList()
        val array = JSONArray(value)
        return (0 until array.length()).map { array.getString(it) }
    }
}

@TypeConverters(Converters::class)
@Database(
    entities = [
        UserProgress::class,
        DailyCheckIn::class,
        UrgeSurfingSession::class,
        ManagedApp::class,
        LocalAnalyticsEvent::class,
    ],
    version = 1,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userProgressDao(): com.manwen.app.data.local.daos.UserProgressDao
    abstract fun dailyCheckInDao(): com.manwen.app.data.local.daos.DailyCheckInDao
    abstract fun urgeSurfingDao(): com.manwen.app.data.local.daos.UrgeSurfingDao
    abstract fun managedAppsDao(): com.manwen.app.data.local.daos.ManagedAppsDao
    abstract fun analyticsDao(): com.manwen.app.data.local.daos.AnalyticsDao

    companion object {
        @Volatile
        private var INSTANCE: AppDatabase? = null

        fun getInstance(context: Context): AppDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "man_wen_db"
                )
                    .fallbackToDestructiveMigration()
                    .build()

                INSTANCE = instance
                instance
            }
        }
    }
}
