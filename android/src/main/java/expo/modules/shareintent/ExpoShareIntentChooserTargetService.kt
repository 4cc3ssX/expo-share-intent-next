package expo.modules.shareintent

import android.content.ComponentName
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.service.chooser.ChooserTarget
import android.service.chooser.ChooserTargetService
import android.util.Log
import org.json.JSONArray

/**
 * A service that provides direct share targets for the ExpoShareIntent module This service requires
 * Android 6.0 (API level 23) or higher
 */
class ExpoShareIntentChooserTargetService : ChooserTargetService() {
    override fun onGetChooserTargets(
            targetActivityName: ComponentName,
            matchedFilter: IntentFilter
    ): List<ChooserTarget> {
        // Early return if Android version is below M (Direct Share API introduced in Android M)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return emptyList()
        }

        try {
            // Get saved contacts from shared preferences
            val prefs = getSharedPreferences("ExpoShareIntentContacts", 0)
            val contacts = getContactsFromPrefs(prefs)

            // Return a list of ChooserTargets representing the contacts
            return contacts.map { contact ->
                val (id, name, imageUrl) = contact

                val intent = Intent(Intent.ACTION_SENDTO)
                val uri = Uri.parse("smsto:$id")
                intent.data = uri

                // Create icon for the contact, use default if no image
                val icon = Icon.createWithResource(this, android.R.drawable.ic_dialog_email)

                ChooserTarget(
                        name,
                        icon,
                        0.8f, // High ranking for direct contacts
                        targetActivityName,
                        Bundle()
                )
            }
        } catch (e: Exception) {
            Log.e("ExpoShareIntent", "Error creating Direct Share targets: ${e.message}")
            return emptyList()
        }
    }

    /** Parse contacts data from shared preferences */
    private fun getContactsFromPrefs(
            prefs: SharedPreferences
    ): List<Triple<String, String, String?>> {
        val contactsJson = prefs.getString("recent_contacts", null) ?: return emptyList()

        try {
            val contactsList = mutableListOf<Triple<String, String, String?>>()
            val jsonArray = JSONArray(contactsJson)

            // Get the most recent contacts (max 5)
            for (i in 0 until minOf(jsonArray.length(), 5)) {
                val contactObj = jsonArray.getJSONObject(i)
                val id = contactObj.getString("id")
                val name = contactObj.getString("name")
                val imageUrl =
                        if (contactObj.has("imageUrl")) contactObj.getString("imageUrl") else null

                contactsList.add(Triple(id, name, imageUrl))
            }

            return contactsList
        } catch (e: Exception) {
            Log.e("ExpoShareIntent", "Error parsing contacts: ${e.message}")
            return emptyList()
        }
    }
}
