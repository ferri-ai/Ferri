package com.ferri.ferri.channels

import android.app.Activity
import android.nfc.NfcAdapter
import android.nfc.tech.Ndef
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * NFC tag reading and writing using foreground reader mode.
 * Waits up to 30 seconds for a tag tap, then returns timeout if none detected.
 * Hardware feature declared with required="false" — availability checked at runtime.
 */
class NfcChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {
    companion object {
        const val CHANNEL_NAME = "ferri/nfc"
        private const val TIMEOUT_MS = 30000L
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> isAvailable(result)
            "readTag" -> readTag(result)
            "writeTag" -> writeTag(call, result)
            else -> result.notImplemented()
        }
    }

    private fun isAvailable(result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(activity)
        result.success(JSONObject().apply {
            put("available", adapter != null)
            put("enabled", adapter?.isEnabled ?: false)
        }.toString())
    }

    private fun readTag(result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(activity)
        if (adapter == null || !adapter.isEnabled) {
            return result.error("NFC_UNAVAILABLE", "NFC is not available or not enabled", null)
        }

        var responded = false
        val handler = Handler(Looper.getMainLooper())

        val callback = NfcAdapter.ReaderCallback { tag ->
            if (responded) return@ReaderCallback
            responded = true
            adapter.disableReaderMode(activity)

            val response = JSONObject().apply {
                put("tag_id", tag.id.joinToString("") { "%02X".format(it) })
                put("tech_list", JSONArray(tag.techList.toList()))

                val ndef = Ndef.get(tag)
                if (ndef != null) {
                    try {
                        ndef.connect()
                        val message = ndef.ndefMessage
                        if (message != null) {
                            val records = JSONArray()
                            for (record in message.records) {
                                records.put(parseNdefRecord(record))
                            }
                            put("records", records)
                        }
                        ndef.close()
                    } catch (e: Exception) {
                        put("ndef_error", e.message ?: "Failed to read NDEF")
                    }
                }
            }
            handler.post { result.success(response.toString()) }
        }

        adapter.enableReaderMode(activity, callback,
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V,
            Bundle())

        handler.postDelayed({
            if (!responded) {
                responded = true
                adapter.disableReaderMode(activity)
                result.success(JSONObject().apply {
                    put("error", "timeout")
                    put("message", "No NFC tag detected within 30 seconds")
                }.toString())
            }
        }, TIMEOUT_MS)
    }

    private fun writeTag(call: MethodCall, result: MethodChannel.Result) {
        val adapter = NfcAdapter.getDefaultAdapter(activity)
        if (adapter == null || !adapter.isEnabled) {
            return result.error("NFC_UNAVAILABLE", "NFC is not available or not enabled", null)
        }

        val text = call.argument<String>("text")
        val url = call.argument<String>("url")

        val record = when {
            url != null -> NdefRecord.createUri(url)
            text != null -> NdefRecord.createTextRecord("en", text)
            else -> return result.error("INVALID_ARGS", "text or url is required", null)
        }

        val message = NdefMessage(arrayOf(record))
        var responded = false
        val handler = Handler(Looper.getMainLooper())

        val callback = NfcAdapter.ReaderCallback { tag ->
            if (responded) return@ReaderCallback
            responded = true
            adapter.disableReaderMode(activity)

            try {
                val ndef = Ndef.get(tag)
                if (ndef == null) {
                    handler.post {
                        result.success(JSONObject().apply {
                            put("success", false)
                            put("error", "Tag does not support NDEF")
                        }.toString())
                    }
                    return@ReaderCallback
                }

                ndef.connect()
                if (!ndef.isWritable) {
                    ndef.close()
                    handler.post {
                        result.success(JSONObject().apply {
                            put("success", false)
                            put("error", "Tag is read-only")
                        }.toString())
                    }
                    return@ReaderCallback
                }

                ndef.writeNdefMessage(message)
                ndef.close()

                handler.post {
                    result.success(JSONObject().apply {
                        put("success", true)
                        put("tag_id", tag.id.joinToString("") { "%02X".format(it) })
                    }.toString())
                }
            } catch (e: Exception) {
                handler.post {
                    result.error("NFC_WRITE_ERROR", "Failed to write tag", e.message)
                }
            }
        }

        adapter.enableReaderMode(activity, callback,
            NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B,
            Bundle())

        handler.postDelayed({
            if (!responded) {
                responded = true
                adapter.disableReaderMode(activity)
                result.success(JSONObject().apply {
                    put("error", "timeout")
                    put("message", "No NFC tag detected within 30 seconds")
                }.toString())
            }
        }, TIMEOUT_MS)
    }

    private fun parseNdefRecord(record: NdefRecord): JSONObject {
        return JSONObject().apply {
            put("tnf", record.tnf)
            when (record.tnf) {
                NdefRecord.TNF_WELL_KNOWN -> {
                    if (record.type.contentEquals(NdefRecord.RTD_TEXT)) {
                        val payload = record.payload
                        val langLen = payload[0].toInt() and 0x3F
                        val text = String(payload, langLen + 1, payload.size - langLen - 1, Charsets.UTF_8)
                        put("type", "text")
                        put("value", text)
                    } else if (record.type.contentEquals(NdefRecord.RTD_URI)) {
                        put("type", "uri")
                        put("value", record.toUri().toString())
                    }
                }
                NdefRecord.TNF_ABSOLUTE_URI -> {
                    put("type", "uri")
                    put("value", String(record.payload, Charsets.UTF_8))
                }
                else -> {
                    put("type", "raw")
                    put("value", record.payload.joinToString("") { "%02X".format(it) })
                }
            }
        }
    }
}
