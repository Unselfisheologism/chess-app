package com.manwen.app.analytics

import android.content.Context
import com.manwen.app.data.local.entities.LocalAnalyticsEvent
import com.manwen.app.data.local.daos.AnalyticsDao
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class AppAnalytics(private val analyticsDao: AnalyticsDao) {

    companion object {
        const val EVENT_APP_OPENED = "app_opened"
        const val EVENT_STREAK_UPDATED = "streak_updated"
        const val EVENT_URGE_SURFING_STARTED = "urge_surfing_started"
        const val EVENT_DAILY_CHECKIN_COMPLETED = "daily_checkin_completed"
        const val EVENT_PAYWALL_VIEWED = "paywall_viewed"
        const val EVENT_PURCHASE_STARTED = "purchase_started"
        const val EVENT_PURCHASE_COMPLETED = "purchase_completed"
        const val EVENT_RELAPSE = "relapse"
    }

    private val scope = CoroutineScope(Dispatchers.IO)

    fun track(eventName: String, properties: Map<String, String> = emptyMap()) {
        scope.launch {
            val event = LocalAnalyticsEvent(
                timestamp = System.currentTimeMillis(),
                eventName = eventName,
                propertiesJson = jsonFromMap(properties)
            )
            analyticsDao.insertEvent(event)
        }
    }

    fun trackStreakUpdated(days: Int) {
        track(EVENT_STREAK_UPDATED, mapOf("days" to days.toString()))
    }

    fun trackPurchaseStarted(plan: String) {
        track(EVENT_PURCHASE_STARTED, mapOf("plan" to plan))
    }

    fun trackPurchaseCompleted(plan: String, revenue: Double) {
        track(EVENT_PURCHASE_COMPLETED, mapOf(
            "plan" to plan,
            "revenue" to revenue.toString()
        ))
    }

    fun exportAll(analyticsDao: AnalyticsDao, onExported: (String) -> Unit) {
        CoroutineScope(Dispatchers.IO).launch {
            val events = analyticsDao.getAllEvents()
            val json = jsonFromList(events)
            launch(Dispatchers.Main) { onExported(json) }
        }
    }

    private fun jsonFromMap(map: Map<String, String>): String {
            val entries = map.entries.joinToString(",") { "\"${it.key}\":\"${it.value}\"" }
            return "{${entries}}"
        }

    private fun jsonFromList(list: List<LocalAnalyticsEvent>): String {
        val items = list.joinToString(",") { e ->
            "{${jsonFromMap(mapOf(
                "id" to e.id.toString(),
                "timestamp" to e.timestamp.toString(),
                "event" to e.eventName,
                "props" to e.propertiesJson
            ))}"
        }
        return "[${items}]"
    }
}