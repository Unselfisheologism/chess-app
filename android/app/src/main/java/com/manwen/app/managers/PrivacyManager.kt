package com.manwen.app.managers

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import java.io.File
import java.io.FileOutputStream

class PrivacyManager(private val context: Context) {

    fun setupEncryptedDatabase(): Boolean {
        return true
    }

    fun setupBiometricLock(activity: Activity, onSuccess: () -> Unit, onError: (String) -> Unit) {
        val biometricManager = BiometricManager.from(activity)
        val canAuth = biometricManager.canAuthenticate(
            androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or
            androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
        )

        if (canAuth != androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS) {
            onError("Biometric not available")
            return
        }

        val executor = ContextCompat.getMainExecutor(activity)
        val biometricPrompt = BiometricPrompt(activity as FragmentActivity, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    onSuccess()
                }
                override fun onAuthenticationFailed() {}
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onError(errString.toString())
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock Man Wen")
            .setSubtitle("Authenticate to access your progress")
            .setAllowedAuthenticators(
                androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG or
                androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    fun secureWipeData() {
        context.deleteDatabase("man_wen_db")
        context.getSharedPreferences("man_wen_prefs", Context.MODE_PRIVATE).edit().clear().apply()

        val filesDir = context.filesDir
        filesDir.listFiles()?.forEach { file ->
            try {
                val outputStream = FileOutputStream(file)
                val zeros = ByteArray(file.length().toInt().coerceAtLeast(1024))
                outputStream.write(zeros)
                outputStream.close()
                file.delete()
            } catch (e: Exception) {
                file.delete()
            }
        }
    }
}
