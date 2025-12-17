package com.example.callad

import android.content.Intent
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log

class MyCallScreeningService : CallScreeningService() {

    override fun onScreenCall(details: Call.Details) {

        val number = details.handle?.schemeSpecificPart
        Log.d("CallScreening", "📞 Incoming call: $number")

        // ✅ Use foreground service for Android 12+
        try {
            androidx.core.content.ContextCompat.startForegroundService(
                this,
                Intent(this, CallOverlayService::class.java).apply {
                    putExtra("PHONE_NUMBER", number)
                }
            )
            Log.d("CallScreening", "✅ Overlay service started")
        } catch (e: Exception) {
            Log.e("CallScreening", "❌ Error starting overlay: ${e.message}")
        }

        respondToCall(
            details,
            CallResponse.Builder().build()
        )
    }
}
