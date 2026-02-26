package com.ferri.ferri.channels

import android.content.Context
import android.media.AudioManager
import android.app.NotificationManager
import android.view.KeyEvent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * Handles audio volume control, ringer mode, DND, and media playback control.
 *
 * Volume and ringer operations use [AudioManager].
 * DND operations use [NotificationManager] and require ACCESS_NOTIFICATION_POLICY.
 * Media control dispatches media key events via [AudioManager].
 */
class AudioChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/audio"
    }

    private val audioManager: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getVolume" -> getVolume(result)
            "setVolume" -> setVolume(call, result)
            "getMode" -> getMode(result)
            "setMode" -> setMode(call, result)
            "mediaControl" -> mediaControl(call, result)
            else -> result.notImplemented()
        }
    }

    private fun getVolume(result: MethodChannel.Result) {
        try {
            val am = audioManager
            val streams = mapOf(
                "music" to AudioManager.STREAM_MUSIC,
                "ring" to AudioManager.STREAM_RING,
                "alarm" to AudioManager.STREAM_ALARM,
                "notification" to AudioManager.STREAM_NOTIFICATION,
                "call" to AudioManager.STREAM_VOICE_CALL,
            )
            val response = JSONObject()
            for ((name, stream) in streams) {
                val current = am.getStreamVolume(stream)
                val max = am.getStreamMaxVolume(stream)
                val pct = if (max > 0) (current * 100 / max) else 0
                response.put(name, JSONObject().apply {
                    put("current", current)
                    put("max", max)
                    put("percent", pct)
                })
            }
            result.success(response.toString())
        } catch (e: Exception) {
            result.error("AUDIO_ERROR", "Failed to get volume", e.message)
        }
    }

    private fun setVolume(call: MethodCall, result: MethodChannel.Result) {
        try {
            val stream = call.argument<String>("stream") ?: "music"
            val percent = call.argument<Int>("percent")
                ?: return result.error("INVALID_ARGS", "percent is required", null)

            val am = audioManager
            val streamType = when (stream) {
                "ring" -> AudioManager.STREAM_RING
                "alarm" -> AudioManager.STREAM_ALARM
                "notification" -> AudioManager.STREAM_NOTIFICATION
                "call" -> AudioManager.STREAM_VOICE_CALL
                else -> AudioManager.STREAM_MUSIC
            }

            val max = am.getStreamMaxVolume(streamType)
            val volume = (percent.coerceIn(0, 100) * max / 100)
            am.setStreamVolume(streamType, volume, 0)

            result.success(JSONObject().apply {
                put("success", true)
                put("stream", stream)
                put("percent", percent)
                put("raw_value", volume)
                put("max_value", max)
            }.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Cannot modify audio settings", e.message)
        } catch (e: Exception) {
            result.error("AUDIO_ERROR", "Failed to set volume", e.message)
        }
    }

    private fun getMode(result: MethodChannel.Result) {
        try {
            val am = audioManager
            val ringerMode = when (am.ringerMode) {
                AudioManager.RINGER_MODE_NORMAL -> "normal"
                AudioManager.RINGER_MODE_VIBRATE -> "vibrate"
                AudioManager.RINGER_MODE_SILENT -> "silent"
                else -> "unknown"
            }

            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val dndEnabled = nm.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL

            result.success(JSONObject().apply {
                put("ringer_mode", ringerMode)
                put("dnd_enabled", dndEnabled)
            }.toString())
        } catch (e: Exception) {
            result.error("AUDIO_ERROR", "Failed to get mode", e.message)
        }
    }

    private fun setMode(call: MethodCall, result: MethodChannel.Result) {
        try {
            val mode = call.argument<String>("mode")
            val dnd = call.argument<Boolean>("dnd")

            val am = audioManager

            if (mode != null) {
                am.ringerMode = when (mode) {
                    "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                    "silent" -> AudioManager.RINGER_MODE_SILENT
                    else -> AudioManager.RINGER_MODE_NORMAL
                }
            }

            if (dnd != null) {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (!nm.isNotificationPolicyAccessGranted) {
                    return result.error("PERMISSION_REQUIRED",
                        "DND requires notification policy access. Enable it in Settings > Apps > Special app access > Do Not Disturb access.",
                        null)
                }
                nm.setInterruptionFilter(
                    if (dnd) NotificationManager.INTERRUPTION_FILTER_PRIORITY
                    else NotificationManager.INTERRUPTION_FILTER_ALL
                )
            }

            result.success(JSONObject().apply {
                put("success", true)
                if (mode != null) put("ringer_mode", mode)
                if (dnd != null) put("dnd_enabled", dnd)
            }.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Cannot modify ringer/DND settings", e.message)
        } catch (e: Exception) {
            result.error("AUDIO_ERROR", "Failed to set mode", e.message)
        }
    }

    private fun mediaControl(call: MethodCall, result: MethodChannel.Result) {
        try {
            val action = call.argument<String>("action")
                ?: return result.error("INVALID_ARGS", "action is required", null)

            val keyCode = when (action) {
                "play" -> KeyEvent.KEYCODE_MEDIA_PLAY
                "pause" -> KeyEvent.KEYCODE_MEDIA_PAUSE
                "play_pause" -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
                "stop" -> KeyEvent.KEYCODE_MEDIA_STOP
                "skip_next", "next" -> KeyEvent.KEYCODE_MEDIA_NEXT
                "skip_previous", "previous" -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
                else -> return result.error("INVALID_ARGS", "Unknown action: $action. Supported: play, pause, play_pause, stop, skip_next, skip_previous", null)
            }

            val am = audioManager
            am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            am.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, keyCode))

            val response = JSONObject().apply {
                put("success", true)
                put("action", action)
            }

            // Try to get now-playing metadata (optional, may fail without notification listener)
            try {
                val msm = context.getSystemService(Context.MEDIA_SESSION_SERVICE) as android.media.session.MediaSessionManager
                val component = android.content.ComponentName(context, com.ferri.ferri.services.FerriNotificationListenerService::class.java)
                val sessions = msm.getActiveSessions(component)
                if (sessions.isNotEmpty()) {
                    val metadata = sessions[0].metadata
                    if (metadata != null) {
                        response.put("now_playing", JSONObject().apply {
                            put("title", metadata.getString(android.media.MediaMetadata.METADATA_KEY_TITLE) ?: "")
                            put("artist", metadata.getString(android.media.MediaMetadata.METADATA_KEY_ARTIST) ?: "")
                            put("album", metadata.getString(android.media.MediaMetadata.METADATA_KEY_ALBUM) ?: "")
                        })
                    }
                }
            } catch (_: Exception) {
                // Media session metadata is optional -- don't fail the whole command
            }

            result.success(response.toString())
        } catch (e: Exception) {
            result.error("MEDIA_ERROR", "Failed media control", e.message)
        }
    }
}
