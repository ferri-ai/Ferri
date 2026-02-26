package com.ferri.ferri.channels

import android.content.ContentValues
import android.content.Context
import android.provider.ContactsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

/**
 * Handles contacts read/write operations via ContactsContract.
 * Registered as a MethodChannel handler in MainActivity.
 */
class ContactsChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "ferri/contacts"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "searchContacts" -> searchContacts(call, result)
            "readContact" -> readContact(call, result)
            "createContact" -> createContact(call, result)
            "updateContact" -> updateContact(call, result)
            "deleteContact" -> deleteContact(call, result)
            else -> result.notImplemented()
        }
    }

    private fun searchContacts(call: MethodCall, result: MethodChannel.Result) {
        try {
            val query = call.argument<String>("query") ?: ""
            val limit = call.argument<Int>("limit") ?: 20

            val projection = arrayOf(
                ContactsContract.Contacts._ID,
                ContactsContract.Contacts.DISPLAY_NAME_PRIMARY,
                ContactsContract.Contacts.HAS_PHONE_NUMBER,
                ContactsContract.Contacts.STARRED
            )

            val selection = if (query.isNotEmpty()) {
                "${ContactsContract.Contacts.DISPLAY_NAME_PRIMARY} LIKE ?"
            } else null
            val selectionArgs = if (query.isNotEmpty()) {
                arrayOf("%$query%")
            } else null

            val cursor = context.contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                projection,
                selection,
                selectionArgs,
                "${ContactsContract.Contacts.DISPLAY_NAME_PRIMARY} ASC"
            )

            val contacts = JSONArray()
            var count = 0
            cursor?.use { c ->
                while (c.moveToNext() && count < limit) {
                    val contactId = c.getLong(0)
                    val contact = JSONObject().apply {
                        put("contact_id", contactId)
                        put("display_name", c.getString(1) ?: "")
                        put("has_phone", c.getInt(2) == 1)
                        put("starred", c.getInt(3) == 1)
                    }
                    contacts.put(contact)
                    count++
                }
            }

            result.success(contacts.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Contacts permission not granted", e.message)
        } catch (e: Exception) {
            result.error("SEARCH_ERROR", "Failed to search contacts", e.message)
        }
    }

    private fun readContact(call: MethodCall, result: MethodChannel.Result) {
        try {
            val contactId = call.argument<String>("contact_id")?.toLongOrNull()
                ?: return result.error("INVALID_ARGS", "contact_id is required", null)

            val contact = JSONObject()
            contact.put("contact_id", contactId)

            // Get display name
            val contactCursor = context.contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                arrayOf(ContactsContract.Contacts.DISPLAY_NAME_PRIMARY),
                "${ContactsContract.Contacts._ID} = ?",
                arrayOf(contactId.toString()),
                null
            )
            contactCursor?.use { c ->
                if (c.moveToFirst()) {
                    contact.put("display_name", c.getString(0) ?: "")
                }
            }

            // Get phone numbers
            val phones = JSONArray()
            val phoneCursor = context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.NUMBER,
                    ContactsContract.CommonDataKinds.Phone.TYPE
                ),
                "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                arrayOf(contactId.toString()),
                null
            )
            phoneCursor?.use { c ->
                while (c.moveToNext()) {
                    val phone = JSONObject().apply {
                        put("number", c.getString(0) ?: "")
                        put("type", ContactsContract.CommonDataKinds.Phone.getTypeLabel(
                            context.resources, c.getInt(1), ""
                        ).toString())
                    }
                    phones.put(phone)
                }
            }
            contact.put("phones", phones)

            // Get emails
            val emails = JSONArray()
            val emailCursor = context.contentResolver.query(
                ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Email.ADDRESS,
                    ContactsContract.CommonDataKinds.Email.TYPE
                ),
                "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
                arrayOf(contactId.toString()),
                null
            )
            emailCursor?.use { c ->
                while (c.moveToNext()) {
                    val email = JSONObject().apply {
                        put("address", c.getString(0) ?: "")
                        put("type", ContactsContract.CommonDataKinds.Email.getTypeLabel(
                            context.resources, c.getInt(1), ""
                        ).toString())
                    }
                    emails.put(email)
                }
            }
            contact.put("emails", emails)

            result.success(contact.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Contacts permission not granted", e.message)
        } catch (e: Exception) {
            result.error("READ_ERROR", "Failed to read contact", e.message)
        }
    }

    private fun createContact(call: MethodCall, result: MethodChannel.Result) {
        try {
            val name = call.argument<String>("name")
                ?: return result.error("INVALID_ARGS", "name is required", null)
            val phone = call.argument<String>("phone")
            val email = call.argument<String>("email")

            val ops = ArrayList<android.content.ContentProviderOperation>()

            // Insert raw contact
            ops.add(
                android.content.ContentProviderOperation
                    .newInsert(ContactsContract.RawContacts.CONTENT_URI)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_TYPE, null)
                    .withValue(ContactsContract.RawContacts.ACCOUNT_NAME, null)
                    .build()
            )

            // Name
            ops.add(
                android.content.ContentProviderOperation
                    .newInsert(ContactsContract.Data.CONTENT_URI)
                    .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                    .withValue(
                        ContactsContract.Data.MIMETYPE,
                        ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE
                    )
                    .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name)
                    .build()
            )

            // Phone
            if (phone != null) {
                ops.add(
                    android.content.ContentProviderOperation
                        .newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                        .withValue(
                            ContactsContract.Data.MIMETYPE,
                            ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
                        )
                        .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                        .withValue(
                            ContactsContract.CommonDataKinds.Phone.TYPE,
                            ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
                        )
                        .build()
                )
            }

            // Email
            if (email != null) {
                ops.add(
                    android.content.ContentProviderOperation
                        .newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValueBackReference(ContactsContract.Data.RAW_CONTACT_ID, 0)
                        .withValue(
                            ContactsContract.Data.MIMETYPE,
                            ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE
                        )
                        .withValue(ContactsContract.CommonDataKinds.Email.ADDRESS, email)
                        .withValue(
                            ContactsContract.CommonDataKinds.Email.TYPE,
                            ContactsContract.CommonDataKinds.Email.TYPE_WORK
                        )
                        .build()
                )
            }

            val results = context.contentResolver.applyBatch(
                ContactsContract.AUTHORITY, ops
            )

            val rawContactId = results[0].uri?.lastPathSegment?.toLongOrNull() ?: -1L
            val response = JSONObject().apply {
                put("raw_contact_id", rawContactId)
                put("name", name)
                put("created", true)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Contacts permission not granted", e.message)
        } catch (e: Exception) {
            result.error("CREATE_ERROR", "Failed to create contact", e.message)
        }
    }

    private fun updateContact(call: MethodCall, result: MethodChannel.Result) {
        try {
            val contactId = call.argument<String>("contact_id")?.toLongOrNull()
                ?: return result.error("INVALID_ARGS", "contact_id is required", null)

            // Get the raw contact ID for this contact
            val rawContactId = getRawContactId(contactId)
                ?: return result.error("NOT_FOUND", "Contact not found", null)

            val ops = ArrayList<android.content.ContentProviderOperation>()

            // Update name if provided
            call.argument<String>("name")?.let { name ->
                ops.add(
                    android.content.ContentProviderOperation
                        .newUpdate(ContactsContract.Data.CONTENT_URI)
                        .withSelection(
                            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                            arrayOf(
                                rawContactId.toString(),
                                ContactsContract.CommonDataKinds.StructuredName.CONTENT_ITEM_TYPE
                            )
                        )
                        .withValue(ContactsContract.CommonDataKinds.StructuredName.DISPLAY_NAME, name)
                        .build()
                )
            }

            // Update phone if provided
            call.argument<String>("phone")?.let { phone ->
                // Delete existing phones and insert new one
                ops.add(
                    android.content.ContentProviderOperation
                        .newDelete(ContactsContract.Data.CONTENT_URI)
                        .withSelection(
                            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                            arrayOf(
                                rawContactId.toString(),
                                ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
                            )
                        )
                        .build()
                )
                ops.add(
                    android.content.ContentProviderOperation
                        .newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                        .withValue(
                            ContactsContract.Data.MIMETYPE,
                            ContactsContract.CommonDataKinds.Phone.CONTENT_ITEM_TYPE
                        )
                        .withValue(ContactsContract.CommonDataKinds.Phone.NUMBER, phone)
                        .withValue(
                            ContactsContract.CommonDataKinds.Phone.TYPE,
                            ContactsContract.CommonDataKinds.Phone.TYPE_MOBILE
                        )
                        .build()
                )
            }

            // Update email if provided
            call.argument<String>("email")?.let { email ->
                ops.add(
                    android.content.ContentProviderOperation
                        .newDelete(ContactsContract.Data.CONTENT_URI)
                        .withSelection(
                            "${ContactsContract.Data.RAW_CONTACT_ID} = ? AND ${ContactsContract.Data.MIMETYPE} = ?",
                            arrayOf(
                                rawContactId.toString(),
                                ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE
                            )
                        )
                        .build()
                )
                ops.add(
                    android.content.ContentProviderOperation
                        .newInsert(ContactsContract.Data.CONTENT_URI)
                        .withValue(ContactsContract.Data.RAW_CONTACT_ID, rawContactId)
                        .withValue(
                            ContactsContract.Data.MIMETYPE,
                            ContactsContract.CommonDataKinds.Email.CONTENT_ITEM_TYPE
                        )
                        .withValue(ContactsContract.CommonDataKinds.Email.ADDRESS, email)
                        .withValue(
                            ContactsContract.CommonDataKinds.Email.TYPE,
                            ContactsContract.CommonDataKinds.Email.TYPE_WORK
                        )
                        .build()
                )
            }

            if (ops.isEmpty()) {
                return result.error("INVALID_ARGS", "No fields to update", null)
            }

            context.contentResolver.applyBatch(ContactsContract.AUTHORITY, ops)
            val response = JSONObject().apply {
                put("contact_id", contactId)
                put("updated", true)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Contacts permission not granted", e.message)
        } catch (e: Exception) {
            result.error("UPDATE_ERROR", "Failed to update contact", e.message)
        }
    }

    private fun deleteContact(call: MethodCall, result: MethodChannel.Result) {
        try {
            val contactId = call.argument<String>("contact_id")?.toLongOrNull()
                ?: return result.error("INVALID_ARGS", "contact_id is required", null)

            val uri = android.content.ContentUris.withAppendedId(
                ContactsContract.Contacts.CONTENT_URI, contactId
            )
            val rowsDeleted = context.contentResolver.delete(uri, null, null)

            val response = JSONObject().apply {
                put("contact_id", contactId)
                put("deleted", rowsDeleted > 0)
            }
            result.success(response.toString())
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", "Contacts permission not granted", e.message)
        } catch (e: Exception) {
            result.error("DELETE_ERROR", "Failed to delete contact", e.message)
        }
    }

    private fun getRawContactId(contactId: Long): Long? {
        val cursor = context.contentResolver.query(
            ContactsContract.RawContacts.CONTENT_URI,
            arrayOf(ContactsContract.RawContacts._ID),
            "${ContactsContract.RawContacts.CONTACT_ID} = ?",
            arrayOf(contactId.toString()),
            null
        )
        cursor?.use { c ->
            if (c.moveToFirst()) {
                return c.getLong(0)
            }
        }
        return null
    }
}
