package com.manwen.app.managers

import android.app.Activity
import android.app.Dialog
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import com.manwen.app.R

class SiteBlockingOverlayManager private constructor() {

    companion object {
        const val TAG = "SiteBlockerOverlay"
        const val ACTION_SHOW_BLOCK = "action.SHOW_BLOCK"
        const val ACTION_HIDE_BLOCK = "action.HIDE_BLOCK"
        
        const val EXTRA_SITE_NAME = "extra.SITE_NAME"

        private var overlayDialog: Dialog? = null
        private var isOverlayShowing = false

        fun handleIntent(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_SHOW_BLOCK -> {
                    val siteName = intent.getStringExtra(EXTRA_SITE_NAME) ?: "this site"
                    showBlockingOverlay(context, siteName)
                }
                ACTION_HIDE_BLOCK -> hideBlockingOverlay()
            }
        }

        fun showBlockingOverlay(context: Context, siteName: String) {
            if (isOverlayShowing) return
            
            // Check if we can draw overlays
            if (!Settings.canDrawOverlays(context)) {
                Log.w(TAG, "Cannot draw overlays - permission not granted")
                Toast.makeText(
                    context,
                    "Please enable overlay permission in settings",
                    Toast.LENGTH_LONG
                ).show()
                return
            }

            try {
                val dialog = Dialog(context, android.R.style.Theme_Translucent_NoTitleBar_Fullscreen)
                
                // Create custom layout
                val contentView = android.widget.LinearLayout(context).apply {
                    orientation = android.widget.LinearLayout.VERTICAL
                    setBackgroundColor(Color.parseColor("#F5F5F5"))
                    setPadding(60, 80, 60, 80)
                    gravity = Gravity.CENTER
                }

                // Shield icon
                val icon = ImageView(context).apply {
                    setImageResource(android.R.drawable.ic_dialog_alert)
                    setColorFilter(Color.parseColor("#D32F2F"))
                    layoutParams = android.widget.LinearLayout.LayoutParams(150, 150)
                }

                // Title
                val title = TextView(context).apply {
                    text = "Site Blocked"
                    textSize = 32f
                    setTextColor(Color.parseColor("#D32F2F"))
                    gravity = Gravity.CENTER
                    setPadding(0, 40, 0, 20)
                }

                // Description
                val description = TextView(context).apply {
                    text = "Man Wen has blocked access to:\n\n$siteName\n\nThis site contains content that you've chosen to avoid."
                    textSize = 18f
                    setTextColor(Color.parseColor("#333333"))
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 40)
                }

                // Message
                val message = TextView(context).apply {
                    text = "You've worked hard to build better habits.\nStay strong and continue your journey."
                    textSize = 14f
                    setTextColor(Color.parseColor("#666666"))
                    gravity = Gravity.CENTER
                    setPadding(0, 0, 0, 40)
                }

                // OK button
                val okButton = Button(context).apply {
                    text = "Continue"
                    textSize = 18f
                    setBackgroundColor(Color.parseColor("#4CAF50"))
                    setTextColor(Color.WHITE)
                    setPadding(40, 20, 40, 20)
                    setOnClickListener {
                        hideBlockingOverlay()
                    }
                }

                // Resources button
                val resourcesButton = Button(context).apply {
                    text = "Get Help"
                    textSize = 14f
                    setBackgroundColor(Color.TRANSPARENT)
                    setTextColor(Color.parseColor("#2196F3"))
                    setOnClickListener {
                        // Open recovery resources
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, 
                                Uri.parse("https://www.reddit.com/r/NoFap/"))
                            context.startActivity(intent)
                        } catch (e: Exception) {
                            Log.w(TAG, "Could not open help URL", e)
                        }
                    }
                }

                contentView.addView(icon)
                contentView.addView(title)
                contentView.addView(description)
                contentView.addView(message)
                contentView.addView(okButton)
                contentView.addView(resourcesButton)

                dialog.setContentView(contentView)
                dialog.window?.apply {
                    setFlags(
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                    )
                    setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        setType(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY)
                    } else {
                        @Suppress("DEPRECATION")
                        setType(WindowManager.LayoutParams.TYPE_SYSTEM_ALERT)
                    }
                }

                dialog.setCancelable(false)
                dialog.show()
                
                overlayDialog = dialog
                isOverlayShowing = true
                
                Log.i(TAG, "Blocking overlay shown for: $siteName")

            } catch (e: Exception) {
                Log.e(TAG, "Failed to show overlay", e)
            }
        }

        fun hideBlockingOverlay() {
            try {
                overlayDialog?.dismiss()
            } catch (e: Exception) {
                Log.w(TAG, "Error dismissing overlay", e)
            }
            overlayDialog = null
            isOverlayShowing = false
        }

        fun isShowing(): Boolean = isOverlayShowing
    }
}