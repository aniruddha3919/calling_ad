package com.example.callad

import android.app.*
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.util.Log
import android.view.*
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.VideoView
import androidx.core.app.NotificationCompat

class CallOverlayService : Service() {

    private lateinit var windowManager: WindowManager
    private var overlayView: View? = null
    private lateinit var params: WindowManager.LayoutParams

    private var startX = 0
    private var startY = 0
    private var touchX = 0f
    private var touchY = 0f

    override fun onCreate() {
        super.onCreate()
        startForegroundSafe()
        showOverlay()
    }

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
    }

    // ---------------- FOREGROUND ----------------

    private fun startForegroundSafe() {
        val channelId = "overlay_channel"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Call Overlay",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    // ---------------- OVERLAY VIDEO ----------------

    private fun showOverlay() {
        if (overlayView != null) return

        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val root = FrameLayout(this)

        // 🎬 Video View
        val videoView = VideoView(this).apply {
            setVideoURI(
                Uri.parse("android.resource://$packageName/${R.raw.ad_video}")
            )

            setOnPreparedListener { mp ->
                mp.isLooping = false
                mp.setVolume(0f, 0f) // 🔇 MUTE (MANDATORY)
                start()
            }

            setOnCompletionListener {
                Log.d("Overlay", "🎬 Video completed")
            }
        }

        // ❌ Close button
        val close = ImageView(this).apply {
            setImageResource(android.R.drawable.ic_menu_close_clear_cancel)
            setPadding(20, 20, 20, 20)
            setOnClickListener { stopSelf() }
        }

        val videoParams = FrameLayout.LayoutParams(
            900, // width (16:9)
            506
        )

        val closeParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.TOP or Gravity.END
        )

        root.addView(videoView, videoParams)
        root.addView(close, closeParams)

        overlayView = root

        params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.CENTER

        // 🧲 Dragging
        root.setOnTouchListener { _, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    startX = params.x
                    startY = params.y
                    touchX = event.rawX
                    touchY = event.rawY
                    true
                }

                MotionEvent.ACTION_MOVE -> {
                    params.x = startX + (event.rawX - touchX).toInt()
                    params.y = startY + (event.rawY - touchY).toInt()
                    windowManager.updateViewLayout(overlayView, params)
                    true
                }

                else -> false
            }
        }

        windowManager.addView(overlayView, params)
        Log.d("CallOverlay", "✅ Video overlay shown")
    }

    private fun removeOverlay() {
        overlayView?.let {
            windowManager.removeView(it)
            overlayView = null
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
