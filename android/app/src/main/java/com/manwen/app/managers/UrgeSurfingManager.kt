package com.manwen.app.managers

import android.content.Context
import android.media.MediaPlayer
import android.os.CountDownTimer
import kotlinx.coroutines.flow.MutableStateFlow

class UrgeSurfingManager(private val context: Context) {

    private var timer: CountDownTimer? = null
    private val _sessionState = MutableStateFlow<SessionState>(SessionState.Idle)
    val sessionState = _sessionState

    sealed class SessionState {
        object Idle : SessionState()
        data class Active(val startTime: Long, val initialUrge: Int, val technique: String) : SessionState()
        data class Completed(val durationSeconds: Int, val finalUrge: Int?) : SessionState()
        data class Cancelled(val message: String = "Session cancelled") : SessionState()
    }

    // Breathing exercise: 4s inhale, 7s hold, 8s exhale (4-7-8)
    fun startBreathingExercise(initialUrge: Int = 5) {
        startSession("4-7-8 Breathing", initialUrge)
    }

    fun startColdShowerTimer(initialUrge: Int = 5) {
        startSession("Cold Shower Timer", initialUrge)
    }

    fun startPushupChallenge(initialUrge: Int = 5) {
        startSession("Push-up Challenge", initialUrge)
    }

    fun startWalkReminder(initialUrge: Int = 5) {
        startSession("Walk Outside", initialUrge)
    }

    private fun startSession(technique: String, initialUrge: Int) {
        timer?.cancel()
        _sessionState.value = SessionState.Active(System.currentTimeMillis(), initialUrge, technique)
    }

    fun completeSession(finalUrge: Int) {
        val current = _sessionState.value
        val duration = if (current is SessionState.Active) {
            ((System.currentTimeMillis() - current.startTime) / 1000).toInt()
        } else 0
        _sessionState.value = SessionState.Completed(duration, finalUrge)
        timer?.cancel()
        timer = null
    }

    fun cancelSession() {
        timer?.cancel()
        timer = null
        _sessionState.value = SessionState.Cancelled()
    }

    fun cleanup() {
        timer?.cancel()
        timer = null
    }
}
