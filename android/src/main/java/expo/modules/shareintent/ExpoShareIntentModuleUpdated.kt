package expo.modules.shareintent

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.util.Log
import expo.modules.kotlin.modules.ModuleDefinition
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject

/** Helper function to save contact information for Direct Share */
private fun saveContactForDirectShare(
        context: Context,
        conversationId: String,
        name: String,
        imageURL: String?
) {
    try {
        // Get shared preferences
        val prefs = context.getSharedPreferences("ExpoShareIntentContacts", 0)

        // Get existing contacts
        val existingContactsJson = prefs.getString("recent_contacts", null)
        val contactsArray =
                if (existingContactsJson != null) {
                    JSONArray(existingContactsJson)
                } else {
                    JSONArray()
                }

        // Check if contact already exists
        var contactExists = false
        for (i in 0 until contactsArray.length()) {
            val contact = contactsArray.getJSONObject(i)
            if (contact.getString("id") == conversationId) {
                // Update existing contact (move to top)
                contactsArray.remove(i)
                contactExists = true
                break
            }
        }

        // Create contact JSON
        val contactJson = JSONObject()
        contactJson.put("id", conversationId)
        contactJson.put("name", name)
        if (imageURL != null) {
            contactJson.put("imageUrl", imageURL)
        }

        // Add to beginning of array
        val newContactsArray = JSONArray()
        newContactsArray.put(contactJson)

        // Add existing contacts (up to max 10)
        val maxContacts = 10
        for (i in 0 until Math.min(contactsArray.length(), maxContacts - 1)) {
            newContactsArray.put(contactsArray.get(i))
        }

        // Save back to preferences
        prefs.edit().putString("recent_contacts", newContactsArray.toString()).apply()
    } catch (e: Exception) {
        Log.e("ExpoShareIntent", "Error saving contact: ${e.message}")
    }
}

/**
 * This function should be inserted into the ExpoShareIntentModule class To be used as a reference
 * implementation
 */
fun sendMessageImplementation() = ModuleDefinition {
    AsyncFunction("sendMessage") {
            conversationIdentifier: String,
            name: String,
            imageURL: String?,
            content: String? ->
        try {
            // Create message sending intent
            val messageUri = Uri.parse("smsto:$conversationIdentifier")
            val sendIntent = Intent(Intent.ACTION_SENDTO, messageUri)

            // Add message content if provided
            content?.let { sendIntent.putExtra("sms_body", it) }

            // Make sure we have a current activity to launch the intent from
            val activity = currentActivity ?: throw Exception("No activity available")

            // Save this contact for Direct Share
            saveContactForDirectShare(context, conversationIdentifier, name, imageURL)

            // Launch the messaging app
            activity.startActivity(sendIntent)

            // Notify JS side
            sendEvent(
                    "onDonate",
                    mapOf(
                            "data" to
                                    mapOf(
                                            "conversationIdentifier" to conversationIdentifier,
                                            "name" to name,
                                            "content" to content
                                    )
                    )
            )

            // Create app shortcut for future use if supported (Android 7.1+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                try {
                    val shortcutManager = activity.getSystemService(ShortcutManager::class.java)

                    // Create an icon for the shortcut
                    val icon =
                            if (imageURL != null) {
                                try {
                                    // Try to load image from URL if provided
                                    val url = URL(imageURL)
                                    val connection = url.openConnection() as HttpURLConnection
                                    connection.doInput = true
                                    connection.connect()
                                    val input = connection.inputStream
                                    val bitmap = BitmapFactory.decodeStream(input)
                                    Icon.createWithBitmap(bitmap)
                                } catch (e: Exception) {
                                    // Fallback to default icon
                                    Icon.createWithResource(
                                            context,
                                            android.R.drawable.ic_dialog_email
                                    )
                                }
                            } else {
                                // Default icon
                                Icon.createWithResource(context, android.R.drawable.ic_dialog_email)
                            }

                    // Create intent for the shortcut
                    val shortcutIntent = Intent(Intent.ACTION_SENDTO, messageUri)
                    shortcutIntent.putExtra("sms_body", content ?: "")

                    // Build the shortcut info
                    val shortcutInfo =
                            ShortcutInfo.Builder(context, "msg_$conversationIdentifier")
                                    .setShortLabel(name)
                                    .setLongLabel("Message $name")
                                    .setIcon(icon)
                                    .setIntent(shortcutIntent)
                                    .build()

                    // Try to add the dynamic shortcut
                    if (shortcutManager != null &&
                                    shortcutManager.dynamicShortcuts.size <
                                            shortcutManager.maxShortcutCountPerActivity
                    ) {
                        shortcutManager.addDynamicShortcuts(listOf(shortcutInfo))
                    }
                } catch (e: Exception) {
                    Log.e("ExpoShareIntent", "Failed to create shortcut: ${e.message}")
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            sendEvent("onError", mapOf("data" to "Error sending message: ${e.message}"))
        }
    }
}
