package com.ferri.ferri.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import org.json.JSONArray
import org.json.JSONObject

class FerriAccessibilityService : AccessibilityService() {

    companion object {
        @Volatile
        var instance: FerriAccessibilityService? = null
            private set

        private var lastActionTimeMs = 0L
        private const val MIN_ACTION_INTERVAL_MS = 1000L

        fun isRunning(): Boolean = instance != null

        fun readScreen(): String {
            val service = instance ?: return JSONObject().apply {
                put("error", "Accessibility service not running")
            }.toString()

            val root = service.rootInActiveWindow ?: return JSONObject().apply {
                put("error", "No active window")
            }.toString()

            val result = JSONObject()
            result.put("package", root.packageName?.toString() ?: "unknown")

            val nodes = JSONArray()
            traverseNode(root, nodes, 0)
            result.put("nodes", nodes)
            result.put("node_count", nodes.length())

            root.recycle()
            return result.toString()
        }

        private fun traverseNode(node: AccessibilityNodeInfo, arr: JSONArray, depth: Int) {
            if (depth > 20) return

            val obj = JSONObject()
            val text = node.text?.toString() ?: ""
            val desc = node.contentDescription?.toString() ?: ""
            val className = node.className?.toString() ?: ""

            if (text.isNotEmpty() || desc.isNotEmpty() || node.isClickable || node.isEditable) {
                obj.put("text", text)
                if (desc.isNotEmpty()) obj.put("description", desc)
                obj.put("class", className.substringAfterLast('.'))

                val bounds = android.graphics.Rect()
                node.getBoundsInScreen(bounds)
                obj.put("bounds", "${bounds.left},${bounds.top},${bounds.right},${bounds.bottom}")

                if (node.isClickable) obj.put("clickable", true)
                if (node.isScrollable) obj.put("scrollable", true)
                if (node.isEditable) obj.put("editable", true)
                if (node.isCheckable) {
                    obj.put("checkable", true)
                    obj.put("checked", node.isChecked)
                }

                val viewId = node.viewIdResourceName
                if (viewId != null) obj.put("id", viewId)

                arr.put(obj)
            }

            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                traverseNode(child, arr, depth + 1)
                child.recycle()
            }
        }

        fun tapByText(text: String): String {
            if (!checkRateLimit()) return errorJson("Rate limited — max 1 action per second")
            val service = instance ?: return errorJson("Service not running")
            val root = service.rootInActiveWindow ?: return errorJson("No active window")

            val nodes = root.findAccessibilityNodeInfosByText(text)
            if (nodes.isNullOrEmpty()) {
                root.recycle()
                return errorJson("No node found with text: $text")
            }

            val target = nodes.firstOrNull { it.isClickable }
                ?: nodes.first()

            val success = if (target.isClickable) {
                target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            } else {
                var parent = target.parent
                var clicked = false
                while (parent != null) {
                    if (parent.isClickable) {
                        clicked = parent.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                        parent.recycle()
                        break
                    }
                    val grandparent = parent.parent
                    parent.recycle()
                    parent = grandparent
                }
                clicked
            }

            nodes.forEach { it.recycle() }
            root.recycle()
            return JSONObject().apply {
                put("success", success)
                put("matched_text", text)
            }.toString()
        }

        fun tapByCoordinates(x: Float, y: Float): String {
            if (!checkRateLimit()) return errorJson("Rate limited — max 1 action per second")
            val service = instance ?: return errorJson("Service not running")

            val path = Path().apply { moveTo(x, y) }
            val gesture = GestureDescription.Builder()
                .addStroke(GestureDescription.StrokeDescription(path, 0, 100))
                .build()

            var success = false
            service.dispatchGesture(gesture, object : GestureResultCallback() {
                override fun onCompleted(gestureDescription: GestureDescription?) {
                    success = true
                }
            }, null)

            Thread.sleep(150)
            return JSONObject().apply {
                put("success", success)
                put("x", x)
                put("y", y)
            }.toString()
        }

        fun scroll(direction: String): String {
            if (!checkRateLimit()) return errorJson("Rate limited — max 1 action per second")
            val service = instance ?: return errorJson("Service not running")
            val root = service.rootInActiveWindow ?: return errorJson("No active window")

            val scrollable = findScrollable(root)
            if (scrollable == null) {
                root.recycle()
                return errorJson("No scrollable container found")
            }

            val action = when (direction.lowercase()) {
                "down", "forward" -> AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
                "up", "backward" -> AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
                else -> {
                    scrollable.recycle()
                    root.recycle()
                    return errorJson("Invalid direction: $direction. Use up/down/forward/backward")
                }
            }

            val success = scrollable.performAction(action)
            scrollable.recycle()
            root.recycle()
            return JSONObject().apply {
                put("success", success)
                put("direction", direction)
            }.toString()
        }

        private fun findScrollable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            if (node.isScrollable) return AccessibilityNodeInfo.obtain(node)
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val found = findScrollable(child)
                child.recycle()
                if (found != null) return found
            }
            return null
        }

        fun typeText(text: String, fieldLabel: String?): String {
            if (!checkRateLimit()) return errorJson("Rate limited — max 1 action per second")
            val service = instance ?: return errorJson("Service not running")
            val root = service.rootInActiveWindow ?: return errorJson("No active window")

            val target: AccessibilityNodeInfo? = if (fieldLabel != null) {
                val nodes = root.findAccessibilityNodeInfosByText(fieldLabel)
                nodes?.firstOrNull { it.isEditable }
                    ?: findFocusedEditable(root)
            } else {
                findFocusedEditable(root)
            }

            if (target == null) {
                root.recycle()
                return errorJson("No editable field found")
            }

            val args = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }
            val success = target.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            target.recycle()
            root.recycle()
            return JSONObject().apply {
                put("success", success)
                put("text_set", text)
            }.toString()
        }

        private fun findFocusedEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            if (node.isEditable && node.isFocused) return AccessibilityNodeInfo.obtain(node)
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val found = findFocusedEditable(child)
                child.recycle()
                if (found != null) return found
            }
            if (node.isEditable) return AccessibilityNodeInfo.obtain(node)
            return null
        }

        private fun checkRateLimit(): Boolean {
            val now = System.currentTimeMillis()
            if (now - lastActionTimeMs < MIN_ACTION_INTERVAL_MS) return false
            lastActionTimeMs = now
            return true
        }

        private fun errorJson(msg: String): String =
            JSONObject().apply { put("error", msg) }.toString()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op: we query on demand via companion methods
    }

    override fun onInterrupt() {
        // Required override
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }
}
