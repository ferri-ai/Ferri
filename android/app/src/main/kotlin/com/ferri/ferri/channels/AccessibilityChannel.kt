package com.ferri.ferri.channels

import android.content.Context
import com.ferri.ferri.services.FerriAccessibilityService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AccessibilityChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/accessibility"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isServiceEnabled" -> {
                result.success(FerriAccessibilityService.isRunning())
            }
            "readScreen" -> {
                try {
                    val json = FerriAccessibilityService.readScreen()
                    result.success(json)
                } catch (e: Exception) {
                    result.error("READ_ERROR", "Failed to read screen", e.message)
                }
            }
            "tap" -> {
                try {
                    val text = call.argument<String>("text")
                    val x = (call.argument<Any>("x") as? Number)?.toFloat()
                    val y = (call.argument<Any>("y") as? Number)?.toFloat()

                    val json = if (text != null) {
                        FerriAccessibilityService.tapByText(text)
                    } else if (x != null && y != null) {
                        FerriAccessibilityService.tapByCoordinates(x, y)
                    } else {
                        result.error("INVALID_ARGS", "Provide 'text' or 'x'+'y' coordinates", null)
                        return
                    }
                    result.success(json)
                } catch (e: Exception) {
                    result.error("TAP_ERROR", "Failed to tap", e.message)
                }
            }
            "scroll" -> {
                try {
                    val direction = call.argument<String>("direction") ?: "down"
                    val json = FerriAccessibilityService.scroll(direction)
                    result.success(json)
                } catch (e: Exception) {
                    result.error("SCROLL_ERROR", "Failed to scroll", e.message)
                }
            }
            "typeText" -> {
                try {
                    val text = call.argument<String>("text")
                        ?: return result.error("INVALID_ARGS", "text is required", null)
                    val fieldLabel = call.argument<String>("field_label")
                    val json = FerriAccessibilityService.typeText(text, fieldLabel)
                    result.success(json)
                } catch (e: Exception) {
                    result.error("TYPE_ERROR", "Failed to type text", e.message)
                }
            }
            else -> result.notImplemented()
        }
    }
}
