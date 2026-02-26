package com.ferri.ferri.channels

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.io.File

/**
 * Handles file picking via Android Storage Access Framework (SAF).
 * Workspace file operations (list, read, write, delete) are handled in Dart.
 * This channel only handles [pickFile] which requires native SAF intents.
 */
class FilesChannel(private val activity: Activity) :
    MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL_NAME = "ferri/files"
        private const val PICK_FILE_REQUEST = 9001
    }

    private var pendingResult: MethodChannel.Result? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pickFile" -> pickFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickFile(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            return result.error("ALREADY_PICKING", "A file pick operation is already in progress", null)
        }
        pendingResult = result
        val mimeType = call.argument<String>("mime_type") ?: "*/*"

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
        }
        activity.startActivityForResult(intent, PICK_FILE_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_FILE_REQUEST) return false

        val result = pendingResult ?: return true
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(JSONObject().apply {
                put("cancelled", true)
            }.toString())
            return true
        }

        try {
            val uri = data.data!!
            val cursor = activity.contentResolver.query(uri, null, null, null, null)
            var name = "unknown"
            var size = 0L
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIdx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    val sizeIdx = it.getColumnIndex(OpenableColumns.SIZE)
                    if (nameIdx >= 0) name = it.getString(nameIdx) ?: "unknown"
                    if (sizeIdx >= 0) size = it.getLong(sizeIdx)
                }
            }

            val mimeType = activity.contentResolver.getType(uri) ?: "*/*"

            // For text files, read content
            var content: String? = null
            if (mimeType.startsWith("text/") || mimeType == "application/json") {
                content = activity.contentResolver.openInputStream(uri)?.bufferedReader()?.readText()
            }

            // For images, copy to workspace
            var localPath: String? = null
            if (mimeType.startsWith("image/")) {
                val destFile = File(activity.filesDir, "workspace/$name")
                destFile.parentFile?.mkdirs()
                activity.contentResolver.openInputStream(uri)?.use { input ->
                    destFile.outputStream().use { output -> input.copyTo(output) }
                }
                localPath = destFile.absolutePath
            }

            result.success(JSONObject().apply {
                put("name", name)
                put("size", size)
                put("mime_type", mimeType)
                put("uri", uri.toString())
                if (content != null) put("content", content)
                if (localPath != null) put("local_path", localPath)
            }.toString())
        } catch (e: Exception) {
            result.error("PICK_ERROR", "Failed to pick file", e.message)
        }

        return true
    }
}
