package expo.modules.shareintent

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.app.Activity
import androidx.core.content.pm.ShortcutManagerCompat

/**
 * Activity that handles direct share intents
 * This Activity will receive intents from the Direct Share feature
 */
class ExpoShareIntentActivity : Activity() {
    
    companion object {
        private const val TAG = "ExpoShareIntent"
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Process the incoming intent
        processIntent(intent)
        
        // Finish this activity and launch the main activity
        finish()
        launchMainActivity()
    }
    
    /**
     * Process the incoming intent to extract conversation ID and shared content
     */
    private fun processIntent(intent: Intent?) {
        if (intent == null) return
        
        try {
            // Get the conversation ID from the shortcut extra
            val conversationId = intent.getStringExtra(Intent.EXTRA_SHORTCUT_ID)
            
            // Store the intent in the singleton for processing
            ExpoShareIntentSingleton.intent = intent
            ExpoShareIntentSingleton.isPending = true
            
            // Report shortcut usage if we have a conversation ID
            if (!conversationId.isNullOrEmpty()) {
                reportShortcutUsed(conversationId)
            }
        } catch (e: Exception) {
            // Log any errors
            Log.e(TAG, "Error processing share intent: ${e.message}")
        }
    }
    
    /**
     * Launch the main activity of the application
     */
    private fun launchMainActivity() {
        val packageManager = packageManager
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        if (launchIntent != null) {
            launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            startActivity(launchIntent)
        }
    }
    
    /**
     * Report that the shortcut was used
     */
    private fun reportShortcutUsed(shortcutId: String) {
        try {
            // Report directly using ShortcutManagerCompat
            ShortcutManagerCompat.reportShortcutUsed(applicationContext, shortcutId)
        } catch (e: Exception) {
            Log.e(TAG, "Error reporting shortcut usage: ${e.message}")
        }
    }
}
