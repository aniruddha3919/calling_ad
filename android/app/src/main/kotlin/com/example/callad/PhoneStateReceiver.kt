package com.example.callad

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat

class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private var overlayShown = false
        private const val TAG = "PhoneStateReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {

        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)

        Log.d(TAG, "📞 State = $state")

        when (state) {

            TelephonyManager.EXTRA_STATE_RINGING -> {

                if (overlayShown) return

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    !Settings.canDrawOverlays(context)
                ) {
                    Log.e(TAG, "❌ Overlay permission missing")
                    return
                }

                overlayShown = true

                ContextCompat.startForegroundService(
                    context,
                    Intent(context, CallOverlayService::class.java)
                )

                Log.d(TAG, "✅ Overlay started")
            }

            TelephonyManager.EXTRA_STATE_IDLE -> {

                if (!overlayShown) return

                overlayShown = false

                context.stopService(
                    Intent(context, CallOverlayService::class.java)
                )

                Log.d(TAG, "🛑 Overlay stopped")
            }
        }
    }
}
