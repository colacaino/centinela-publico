package com.example.centinela

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val volumeChannel = "centinela/volumen_alarma"
    private val permissionsChannel = "centinela/permisos"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, volumeChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getAlarmVolume" -> result.success(audio.getStreamVolume(AudioManager.STREAM_ALARM))
                        "getAlarmMaxVolume" -> result.success(audio.getStreamMaxVolume(AudioManager.STREAM_ALARM))
                        "setAlarmVolume" -> {
                            val requested = call.argument<Int>("volume") ?: 0
                            val safeValue = requested.coerceIn(0, audio.getStreamMaxVolume(AudioManager.STREAM_ALARM))
                            audio.setStreamVolume(AudioManager.STREAM_ALARM, safeValue, 0)
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("VOLUME_ERROR", "No se pudo ajustar el volumen de alarma.", null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, permissionsChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "puedeFullScreen" -> result.success(canUseFullScreen())
                        "pedirFullScreen" -> {
                            openFullScreenSettings()
                            result.success(true)
                        }
                        "ignoraBateria" -> result.success(isBatteryOptimizationExempt())
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("PERMISSION_ERROR", "No se pudo consultar el ajuste.", null)
                }
            }
    }

    private fun canUseFullScreen(): Boolean = if (Build.VERSION.SDK_INT >= 34) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.canUseFullScreenIntent()
    } else {
        true
    }

    private fun openFullScreenSettings() {
        if (Build.VERSION.SDK_INT >= 34) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:$packageName")
                )
            )
        }
    }

    private fun isBatteryOptimizationExempt(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        return power.isIgnoringBatteryOptimizations(packageName)
    }
}
