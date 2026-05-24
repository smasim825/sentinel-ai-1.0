package com.example.sentinel

import android.content.Intent
import android.service.quicksettings.TileService
import android.service.quicksettings.Tile

class SentinelTileService : TileService() {
    override fun onClick() {
        super.onClick()
        
        // Collapse the status bar (notification drawer)
        val closeIntent = Intent(Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
        sendBroadcast(closeIntent)

        // Launch the app with the SOS trigger action
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "ACTION_TRIGGER_SOS"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        startActivityAndCollapse(intent)
    }

    override fun onStartListening() {
        super.onStartListening()
        val tile = qsTile
        tile.label = "Sentinel SOS"
        tile.state = Tile.STATE_INACTIVE
        tile.updateTile()
    }
}
