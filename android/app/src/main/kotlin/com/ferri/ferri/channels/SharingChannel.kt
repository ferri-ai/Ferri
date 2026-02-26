package com.ferri.ferri.channels

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File

/**
 * Handles sharing text and files via Android Sharesheet.
 */
class SharingChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/sharing"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shareText" -> shareText(call, result)
            "shareFile" -> shareFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun shareText(call: MethodCall, result: MethodChannel.Result) {
        try {
            val text = call.argument<String>("text")
                ?: return result.error("INVALID_ARGS", "text is required", null)
            val subject = call.argument<String>("subject")

            val intent = Intent.createChooser(
                Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, text)
                    if (subject != null) putExtra(Intent.EXTRA_SUBJECT, subject)
                }, null
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }

            context.startActivity(intent)
            result.success(JSONObject().apply {
                put("success", true)
                put("type", "text")
            }.toString())
        } catch (e: android.content.ActivityNotFoundException) {
            result.error("NO_SHARE_TARGET", "No app available to handle sharing", e.message)
        } catch (e: Exception) {
            result.error("SHARE_ERROR", "Failed to share text", e.message)
        }
    }

    private fun shareFile(call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")
                ?: return result.error("INVALID_ARGS", "path is required", null)
            val mimeType = call.argument<String>("mime_type") ?: "*/*"

            val file = File(path)
            if (!file.exists()) {
                return result.error("NOT_FOUND", "File not found: $path", null)
            }

            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file
            )

            val intent = Intent.createChooser(
                Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }, null
            ).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }

            context.startActivity(intent)
            result.success(JSONObject().apply {
                put("success", true)
                put("type", "file")
                put("file_name", file.name)
            }.toString())
        } catch (e: IllegalArgumentException) {
            result.error("FILE_PROVIDER_ERROR", "File is outside FileProvider paths", e.message)
        } catch (e: android.content.ActivityNotFoundException) {
            result.error("NO_SHARE_TARGET", "No app available to handle sharing", e.message)
        } catch (e: Exception) {
            result.error("SHARE_ERROR", "Failed to share file", e.message)
        }
    }
}
