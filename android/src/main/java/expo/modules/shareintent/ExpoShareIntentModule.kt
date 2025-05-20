`
package expo.modules.shareintent

import android.annotation.SuppressLint
import android.app.Activity
import android.content.ContentResolver
import android.content.ContentUris
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Parcelable
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import expo.modules.kotlin.exception.Exceptions
import expo.modules.kotlin.`modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.io.File
import java.io.FileOutputStream
import java.util.Date

/**
 * Expo module for handling shared content from other apps
 */
class ExpoShareIntentModule : Module() {
    /**
     * The application context
     */
    private val context: Context
        get() = appContext.reactContext ?: throw Exceptions.ReactContextLost()
        
    /**
     * Current activity if available
     */
    private val currentActivity: Activity?
        get() = appContext.currentActivity
        
    companion object {
        private var instance: ExpoShareIntentModule? = null
        
        /**
         * Notifies about received share intent with the shared content
         * @param value The shared content details
         */
        private fun notifyShareIntent(value: Any) {
            notifyState("pending")
            instance?.sendEvent("onChange", mapOf("value" to value))
        }
        
        /**
         * Notifies about state changes
         * @param state Current state
         */
        private fun notifyState(state: String) {
            instance?.sendEvent("onStateChange", mapOf("value" to state))
        }
        
        /**
         * Notifies about errors
         * @param message Error message
         */
        private fun notifyError(message: String) {
            instance?.sendEvent("onError", mapOf("value" to message))
        }

        /**
         * Extracts file information from a URI
         * @param uri Content URI
         * @return Map containing file details
         */
        @SuppressLint("Range")
        private fun getFileInfo(uri: Uri): Map<String, String?> {
            // Get content resolver
            val resolver = getContentResolver()
            if (resolver == null) {
                notifyError("Cannot get resolver (getFileInfo)")
                return createBasicFileInfo(uri)
            }
            
            // Query file metadata
            return try {
                val queryResult = resolver.query(uri, null, null, null, null)
                    ?: return createBasicFileInfo(uri)
                
                // Extract basic file information
                queryResult.use { cursor ->
                    cursor.moveToFirst()
                    val fileInfo = extractFileInfoFromCursor(cursor, resolver, uri)
                    
                    // Extract media-specific information based on mime type
                    when {
                        fileInfo["mimeType"]?.startsWith("image/") == true -> 
                            fileInfo + extractImageDimensions(resolver, uri)
                        fileInfo["mimeType"]?.startsWith("video/") == true -> 
                            fileInfo + extractVideoMetadata(uri)
                        else -> fileInfo
                    }
                }
            } catch (e: Exception) {
                notifyError("Error getting file info: ${e.message}")
                createBasicFileInfo(uri)
            }
        }
        
        /**
         * Creates basic file info when detailed info can't be retrieved
         */
        private fun createBasicFileInfo(uri: Uri): Map<String, String?> = mapOf(
            "contentUri" to uri.toString(),
            "filePath" to instance?.getAbsolutePath(uri)
        )
        
        /**
         * Extracts basic file information from cursor
         */
        @SuppressLint("Range")
        private fun extractFileInfoFromCursor(
            cursor: Cursor, 
            resolver: ContentResolver, 
            uri: Uri
        ): Map<String, String?> = mapOf(
            "contentUri" to uri.toString(),
            "filePath" to instance?.getAbsolutePath(uri),
            "fileName" to cursor.getString(cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)),
            "fileSize" to cursor.getString(cursor.getColumnIndex(OpenableColumns.SIZE)),
            "mimeType" to resolver.getType(uri)
        )
        
        /**
         * Gets the content resolver from instance
         */
        private fun getContentResolver(): ContentResolver? = 
            instance?.currentActivity?.contentResolver ?: instance?.context?.contentResolver
        
        /**
         * Extracts image dimensions from an image URI
         */
        private fun extractImageDimensions(resolver: ContentResolver, uri: Uri): Map<String, String?> {
            return try {
                val options = BitmapFactory.Options().apply {
                    inJustDecodeBounds = true
                }
                BitmapFactory.decodeStream(resolver.openInputStream(uri), null, options)
                
                mapOf(
                    "width" to options.outWidth.toString(),
                    "height" to options.outHeight.toString()
                )
            } catch (e: Exception) {
                mapOf(
                    "width" to null,
                    "height" to null
                )
            }
        }
        
        /**
         * Extracts video metadata from a video URI
         */
        private fun extractVideoMetadata(uri: Uri): Map<String, String?> {
            return try {
                val filePath = instance?.getAbsolutePath(uri) ?: return emptyMap()
                val retriever = MediaMetadataRetriever()
                retriever.setDataSource(filePath)
                
                // Extract basic dimensions
                var width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                var height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                
                // Check orientation and flip dimensions if needed
                val metaRotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toInt() ?: 0
                if (metaRotation == 90 || metaRotation == 270) {
                    val temp = width
                    width = height
                    height = temp
                }
                
                mapOf(
                    "width" to width,
                    "height" to height,
                    "duration" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                )
            } catch (e: Exception) {
                mapOf(
                    "width" to null,
                    "height" to null,
                    "duration" to null
                )
            }
        }

        /**
         * Handles intent with shared content
         * @param intent The received intent
         */
        fun handleShareIntent(intent: Intent) {
            // Early return if no type
            val intentType = intent.type ?: return
            
            when {
                // Handle text/plain content
                intentType.startsWith("text/plain") -> handleTextShare(intent)
                
                // Handle file content
                else -> handleFileShare(intent)
            }
        }
        
        /**
         * Handles text or URL sharing
         */
        private fun handleTextShare(intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SEND -> {
                    notifyShareIntent(mapOf(
                        "text" to intent.getStringExtra(Intent.EXTRA_TEXT),
                        "type" to "text",
                        "meta" to mapOf(
                            "title" to intent.getCharSequenceExtra(Intent.EXTRA_TITLE),
                        )
                    ))
                }
                Intent.ACTION_VIEW -> {
                    notifyShareIntent(mapOf(
                        "text" to intent.dataString, 
                        "type" to "text"
                    ))
                }
                else -> {
                    notifyError("Invalid action for text sharing: ${intent.action}")
                }
            }
        }
        
        /**
         * Handles file sharing (single or multiple)
         */
        private fun handleFileShare(intent: Intent) {
            when (intent.action) {
                Intent.ACTION_SEND -> {
                    val uri = intent.parcelable<Uri>(Intent.EXTRA_STREAM)
                    if (uri != null) {
                        notifyShareIntent(mapOf(
                            "files" to arrayOf(getFileInfo(uri)), 
                            "type" to "file"
                        ))
                    } else {
                        notifyError("Empty uri for file sharing: ${intent.action}")
                    }
                }
                Intent.ACTION_SEND_MULTIPLE -> {
                    val uris = intent.parcelableArrayList<Uri>(Intent.EXTRA_STREAM)
                    if (uris != null) {
                        notifyShareIntent(mapOf(
                            "files" to uris.map { getFileInfo(it) }, 
                            "type" to "file"
                        ))
                    } else {
                        notifyError("Empty uris array for file sharing: ${intent.action}")
                    }
                }
                else -> {
                    notifyError("Invalid action for file sharing: ${intent.action}")
                }
            }
        }
        
        /*
         * https://stackoverflow.com/questions/73019160/the-getparcelableextra-method-is-deprecated
         */
        private inline fun <reified T : Parcelable> Intent.parcelable(key: String): T? = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> getParcelableExtra(key, T::class.java)
            else -> @Suppress("DEPRECATION") getParcelableExtra(key) as? T
        }

        private inline fun <reified T : Parcelable> Intent.parcelableArrayList(key: String): ArrayList<T>? = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> getParcelableArrayListExtra(key, T::class.java)
            else -> @Suppress("DEPRECATION") getParcelableArrayListExtra(key)
        }
    }

    // See https://docs.expo.dev/modules/module-api
    override fun definition() = ModuleDefinition {
        Name("ExpoShareIntentModule")

        Events("onChange", "onStateChange", "onError")

        AsyncFunction("getShareIntent") { _: String ->
            // get the Intent from onCreate activity (app not running in background)
            ExpoShareIntentSingleton.isPending = false
            if (ExpoShareIntentSingleton.intent?.type != null) {
                handleShareIntent(ExpoShareIntentSingleton.intent!!);
                ExpoShareIntentSingleton.intent = null
            }
        }

        Function("clearShareIntent") { _: String ->
            ExpoShareIntentSingleton.intent = null
        }

        Function("hasShareIntent") { _: String ->
            ExpoShareIntentSingleton.isPending
        }

        OnNewIntent {
            handleShareIntent(it)
        }

        OnCreate {
            instance = this@ExpoShareIntentModule
        }

        OnDestroy {
            instance = null
        }
    }

    /**
     * Get a file path from a Uri. This will get the path for Storage Access
     * Framework Documents, as well as the _data field for the MediaStore and
     * other file-based ContentProviders.
     *
     * @param uri The Uri to query.
     * @return The absolute file path or null if not found
     */
    fun getAbsolutePath(uri: Uri): String? {
        return try {
            when {
                // Handle document URIs through the DocumentProvider
                DocumentsContract.isDocumentUri(context, uri) -> getDocumentProviderPath(uri)
                
                // Handle content scheme URIs
                "content".equals(uri.scheme, ignoreCase = true) -> getDataColumn(uri, null, null)
                
                // Default to the URI path for other schemes
                else -> uri.path
            }
        } catch (e: Exception) {
            e.printStackTrace()
            notifyError("Cannot retrieve absoluteFilePath for $uri: ${e.message}")
            null
        }
    }
    
    /**
     * Handles document provider URIs based on their authority
     */
    private fun getDocumentProviderPath(uri: Uri): String? {
        val docId = DocumentsContract.getDocumentId(uri)
        
        return when {
            // External storage documents
            isExternalStorageDocument(uri) -> handleExternalStorageDocument(docId)
            
            // Downloads documents
            isDownloadsDocument(uri) -> handleDownloadsDocument(uri, docId)
            
            // Media documents (images, videos, audio)
            isMediaDocument(uri) -> handleMediaDocument(uri, docId)
            
            // Other document types
            else -> null
        }
    }
    
    /**
     * Handles external storage document URIs
     */
    private fun handleExternalStorageDocument(docId: String): String? {
        val split = docId.split(":", limit = 2)
        val type = split[0]
        
        return if ("primary".equals(type, ignoreCase = true) && split.size > 1) {
            "${Environment.getExternalStorageDirectory()}/${split[1]}"
        } else {
            getDataColumn(uri = Uri.parse(docId), selection = null, selectionArgs = null)
        }
    }
    
    /**
     * Handles downloads document URIs
     */
    private fun handleDownloadsDocument(uri: Uri, docId: String): String? {
        return try {
            val contentUri = ContentUris.withAppendedId(
                Uri.parse("content://downloads/public_downloads"),
                docId.toLong()
            )
            getDataColumn(contentUri, null, null)
        } catch (e: Exception) {
            // Fallback if parsing fails
            getDataColumn(uri, null, null)
        }
    }
    
    /**
     * Handles media document URIs (images, videos, audio)
     */
    private fun handleMediaDocument(uri: Uri, docId: String): String? {
        val split = docId.split(":", limit = 2)
        val type = split[0]
        
        // Early return if we don't have the expected format
        if (split.size < 2) return null
        
        // Select the appropriate content URI based on media type
        val contentUri = when (type) {
            "image" -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            "video" -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            "audio" -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            else -> return null
        }
        
        // Query the content provider
        val selection = "_id=?"
        val selectionArgs = arrayOf(split[1])
        return getDataColumn(contentUri, selection, selectionArgs)
    }

    /**
     * Get the value of the data column for this Uri. This is useful for
     * MediaStore Uris, and other file-based ContentProviders.
     *
     * @param uri The Uri to query.
     * @param selection (Optional) Filter used in the query.
     * @param selectionArgs (Optional) Selection arguments used in the query.
     * @return The value of the _data column, which is typically a file path.
     */
    private fun getDataColumn(uri: Uri, selection: String?, selectionArgs: Array<String>?): String? {
        // Get content resolver
        val resolver = getContentResolver() ?: run {
            notifyError("Cannot get resolver (getDataColumn)")
            return null
        }
        
        // Handle content with authority by copying to cache
        if (uri.authority != null) {
            return copyUriToCache(uri, resolver, selection, selectionArgs)
        }
        
        // Otherwise try to get the direct file path
        return queryForDataColumn(resolver, uri, selection, selectionArgs)
    }
    
    /**
     * Copies URI content to cache directory and returns the path
     */
    private fun copyUriToCache(
        uri: Uri, 
        resolver: ContentResolver,
        selection: String?, 
        selectionArgs: Array<String>?
    ): String? {
        // Try to get the filename
        val targetFile = getTargetFile(uri, resolver, selection, selectionArgs) ?: return null
        
        // Copy the file content
        try {
            resolver.openInputStream(uri)?.use { input ->
                FileOutputStream(targetFile).use { output ->
                    input.copyTo(output)
                }
            }
            return targetFile.path
        } catch (e: Exception) {
            notifyError("Failed to copy file: ${e.message}")
            return null
        }
    }
    
    /**
     * Creates a target file in cache, either with original name or generated name
     */
    private fun getTargetFile(
        uri: Uri, 
        resolver: ContentResolver,
        selection: String?, 
        selectionArgs: Array<String>?
    ): File? {
        // Try to get the original filename
        return try {
            resolver.query(uri, arrayOf("_display_name"), selection, selectionArgs, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val columnIndex = cursor.getColumnIndexOrThrow("_display_name")
                    val fileName = cursor.getString(columnIndex)
                    Log.i("FileDirectory", "File name: $fileName")
                    File(context.cacheDir, fileName)
                } else {
                    createGenericFile(uri, resolver)
                }
            } ?: createGenericFile(uri, resolver)
        } catch (e: Exception) {
            createGenericFile(uri, resolver)
        }
    }
    
    /**
     * Creates a generic file name based on mime type
     */
    private fun createGenericFile(uri: Uri, resolver: ContentResolver): File {
        val mimeType = resolver.getType(uri)
        val prefix = with(mimeType ?: "") {
            when {
                startsWith("image") -> "IMG"
                startsWith("video") -> "VID"
                else -> "FILE"
            }
        }
        val extension = MimeTypeMap.getSingleton().getExtensionFromMimeType(mimeType) ?: ""
        return File(context.cacheDir, "${prefix}_${Date().time}.${extension}")
    }
    
    /**
     * Queries for _data column to get direct file path
     */
    private fun queryForDataColumn(
        resolver: ContentResolver,
        uri: Uri,
        selection: String?,
        selectionArgs: Array<String>?
    ): String? {
        return resolver.query(uri, arrayOf("_data"), selection, selectionArgs, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val columnIndex = cursor.getColumnIndexOrThrow("_data")
                cursor.getString(columnIndex)
            } else {
                null
            }
        }
    }
    
    /**
     * Gets the content resolver from instance
     */
    private fun getContentResolver(): ContentResolver? = 
        currentActivity?.contentResolver ?: context.contentResolver

    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is ExternalStorageProvider.
     */
    private fun isExternalStorageDocument(uri: Uri): Boolean {
        return "com.android.externalstorage.documents" == uri.authority
    }

    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is DownloadsProvider.
     */
    private fun isDownloadsDocument(uri: Uri): Boolean {
        return "com.android.providers.downloads.documents" == uri.authority
    }

    /**
     * @param uri The Uri to check.
     * @return Whether the Uri authority is MediaProvider.
     */
    private fun isMediaDocument(uri: Uri): Boolean {
        return "com.android.providers.media.documents" == uri.authority
    }
}