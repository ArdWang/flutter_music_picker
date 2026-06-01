package com.rnd.flutter_music_picker

import android.content.Context
import android.media.MediaMetadataRetriever
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Android implementation of flutter_music_picker.
 *
 * Uses [RingtoneManager] to discover system ringtones, notification sounds,
 * and alarm tones — the same API used by the Android Settings app.
 * RingtoneManager queries the internal MediaStore database directly and
 * returns valid content:// URIs for every system ringtone.
 *
 * This is the same approach used in the flutter_rt620 project:
 * ```
 * val manager = RingtoneManager(this)
 * manager.setType(RingtoneManager.TYPE_ALARM)
 * val cursor = manager.cursor
 * ```
 */
class FlutterMusicPickerPlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        const val CHANNEL = "com.rnd.flutter_music_picker/music_picker"
        private const val TAG = "FlutterMusicPicker"
    }

    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var currentRingtone: Ringtone? = null

    // ------------------------------------------------------------------
    // FlutterPlugin lifecycle
    // ------------------------------------------------------------------

    override fun onAttachedToEngine(
        @NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding
    ) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        Log.d(TAG, "onAttachedToEngine — handler registered for $CHANNEL")
    }

    override fun onDetachedFromEngine(
        @NonNull binding: FlutterPlugin.FlutterPluginBinding
    ) {
        Log.d(TAG, "onDetachedFromEngine")
        stopRingtone()
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    // ------------------------------------------------------------------
    // Method call dispatch
    // ------------------------------------------------------------------

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")
        try {
            when (call.method) {
                "getMusicFiles" -> {
                    val music = getMusicFiles()
                    Log.d(TAG, "getMusicFiles → ${music.size} tracks")
                    result.success(music)
                }
                "getRingtones" -> {
                    val ringtones = getRingtones()
                    Log.d(TAG, "getRingtones → ${ringtones.size} items")
                    result.success(ringtones)
                }
                "playRingtone" -> {
                    val uri = call.argument<String>("uri") ?: ""
                    Log.d(TAG, "playRingtone: $uri")
                    playRingtone(uri)
                    result.success(true)
                }
                "stopRingtone" -> {
                    stopRingtone()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling ${call.method}", e)
            result.error("ERROR", e.message, null)
        }
    }

    // ==================================================================
    // Music — from MediaStore (RingtoneManager doesn't handle music)
    // ==================================================================

    /**
     * Queries MediaStore for music tracks (IS_MUSIC = 1) on both
     * external and internal storage.
     */
    private fun getMusicFiles(): List<Map<String, Any?>> {
        val context = applicationContext ?: return emptyList()
        val items = mutableListOf<Map<String, Any?>>()

        val projection = arrayOf(
            android.provider.MediaStore.Audio.Media._ID,
            android.provider.MediaStore.Audio.Media.TITLE,
            android.provider.MediaStore.Audio.Media.ARTIST,
            android.provider.MediaStore.Audio.Media.ALBUM,
            android.provider.MediaStore.Audio.Media.DURATION,
            android.provider.MediaStore.Audio.Media.SIZE,
            android.provider.MediaStore.Audio.Media.DATA
        )
        val selection = "${android.provider.MediaStore.Audio.Media.IS_MUSIC} = 1"
        val sort = "${android.provider.MediaStore.Audio.Media.TITLE} ASC"

        val uris = listOf(
            android.provider.MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            android.provider.MediaStore.Audio.Media.INTERNAL_CONTENT_URI
        )

        for (contentUri in uris) {
            var cursor: android.database.Cursor? = null
            try {
                cursor = context.contentResolver.query(
                    contentUri, projection, selection, null, sort
                )
                if (cursor != null && cursor.moveToFirst()) {
                    val idCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media._ID)
                    val tiCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.TITLE)
                    val arCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.ARTIST)
                    val alCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.ALBUM)
                    val duCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.DURATION)
                    val szCol = cursor.getColumnIndexOrThrow(android.provider.MediaStore.Audio.Media.SIZE)
                    do {
                        val id = cursor.getLong(idCol)
                        val title = cursor.getString(tiCol) ?: "Unknown"
                        val artist = cursor.getString(arCol) ?: "Unknown"
                        val album = cursor.getString(alCol) ?: "Unknown"
                        val duration = cursor.getLong(duCol)
                        val size = cursor.getLong(szCol)

                        val trackUri = android.content.ContentUris.withAppendedId(
                            contentUri, id
                        )

                        items.add(mapOf<String, Any?>(
                            "id" to id.toString(),
                            "title" to title,
                            "artist" to artist,
                            "album" to album,
                            "durationMs" to duration.toInt(),
                            "uri" to trackUri.toString(),
                            "sizeBytes" to size.toInt(),
                            "isRingtone" to false
                        ))
                    } while (cursor.moveToNext())
                }
                cursor?.close()
            } catch (e: SecurityException) {
                Log.w(TAG, "Permission denied for music query on $contentUri")
                cursor?.close()
            } catch (e: Exception) {
                Log.w(TAG, "Music query failed for $contentUri: ${e.message}")
                cursor?.close()
            }
        }

        return items
    }

    // ==================================================================
    // Ringtones — RingtoneManager (identical to the working pattern)
    // ==================================================================

    /**
     * Gathers ringtones using [RingtoneManager] — the exact same
     * approach used in the working flutter_rt620 MainActivity.
     *
     * Queries TYPE_RINGTONE, TYPE_NOTIFICATION, and TYPE_ALARM
     * separately, and constructs the content URI by concatenating
     * URI_COLUMN_INDEX + "/" + ID_COLUMN_INDEX.
     *
     * A "None" entry is always prepended as the first option.
     */
    private fun getRingtones(): List<Map<String, Any?>> {
        val context = applicationContext ?: return emptyList()
        val list = mutableListOf<Map<String, Any?>>()

        // "None" — always the first entry (same as working project)
        list.add(mapOf<String, Any?>(
            "id" to "none",
            "title" to "None",
            "artist" to "",
            "album" to "",
            "durationMs" to 0,
            "uri" to "",
            "sizeBytes" to 0,
            "isRingtone" to true
        ))

        // Query each type separately using RingtoneManager
        list.addAll(queryRingtoneType(context, RingtoneManager.TYPE_RINGTONE, "Alert"))
        list.addAll(queryRingtoneType(context, RingtoneManager.TYPE_NOTIFICATION, "Alert"))
        list.addAll(queryRingtoneType(context, RingtoneManager.TYPE_ALARM, "Alert"))

        return list
    }

    /**
     * Queries RingtoneManager for a single ringtone type.
     *
     * This is the exact pattern from the working flutter_rt620 project:
     * - Creates RingtoneManager(context)
     * - Sets the type via setType()
     * - Reads TITLE_COLUMN_INDEX, URI_COLUMN_INDEX, ID_COLUMN_INDEX
     * - Constructs URI as: URI_COLUMN + "/" + ID_COLUMN
     */
    private fun queryRingtoneType(
        context: Context,
        type: Int,
        typeLabel: String
    ): List<Map<String, Any?>> {
        val manager = RingtoneManager(context)
        manager.setType(type)
        val cursor = manager.cursor
        val list = mutableListOf<Map<String, Any?>>()

        if (cursor == null) {
            Log.w(TAG, "RingtoneManager cursor is null for type $typeLabel")
            return list
        }

        if (!cursor.moveToFirst()) {
            Log.d(TAG, "No ringtones found for $typeLabel")
            cursor.close()
            return list
        }

        val album = when (type) {
            RingtoneManager.TYPE_RINGTONE -> "Alerts"
            RingtoneManager.TYPE_NOTIFICATION -> "Alerts"
            RingtoneManager.TYPE_ALARM -> "Alerts"
            else -> "System Sounds"
        }

        do {
            // Exact same pattern as the working flutter_rt620 MainActivity:
            val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
                ?: "Unknown"
            val uriBase = cursor.getString(RingtoneManager.URI_COLUMN_INDEX) ?: ""
            val id = cursor.getString(RingtoneManager.ID_COLUMN_INDEX) ?: ""

            // Build URI: URI_COLUMN + "/" + ID_COLUMN
            val fullUri = if (uriBase.isNotEmpty() && id.isNotEmpty()) {
                "$uriBase/$id"
            } else {
                ""
            }

            val durationMs = if (fullUri.isNotEmpty()) {
                try {
                    val retriever = MediaMetadataRetriever()
                    retriever.setDataSource(context, Uri.parse(fullUri))
                    val durStr = retriever.extractMetadata(
                        MediaMetadataRetriever.METADATA_KEY_DURATION
                    )
                    retriever.release()
                    durStr?.toIntOrNull() ?: 0
                } catch (_: Exception) {
                    0
                }
            } else {
                0
            }

            list.add(mapOf<String, Any?>(
                "id" to id,
                "title" to "$title ($typeLabel)",
                "artist" to "System",
                "album" to album,
                "durationMs" to durationMs,
                "uri" to fullUri,
                "sizeBytes" to 0,        // RingtoneManager doesn't expose size
                "isRingtone" to true
            ))
        } while (cursor.moveToNext())

        cursor.close()
        Log.d(TAG, "Found ${list.size} $typeLabel ringtones")
        return list
    }

    // ==================================================================
    // Ringtone Playback
    // ==================================================================

    private fun playRingtone(uriString: String) {
        stopRingtone()
        if (uriString.isEmpty() || uriString == "none") return
        try {
            val context = applicationContext ?: return
            val uri = Uri.parse(uriString)
            currentRingtone = RingtoneManager.getRingtone(context, uri)
            currentRingtone?.play()
        } catch (e: Exception) {
            Log.e(TAG, "playRingtone failed: $uriString", e)
            currentRingtone = null
        }
    }

    private fun stopRingtone() {
        currentRingtone?.stop()
        currentRingtone = null
    }
}
