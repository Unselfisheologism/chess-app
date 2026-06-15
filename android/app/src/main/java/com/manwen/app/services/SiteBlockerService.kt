package com.manwen.app.services

import android.app.*
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.manwen.app.MainActivity
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.nio.ByteBuffer
import java.nio.ByteOrder

class SiteBlockerService : VpnService() {

    companion object {
        const val TAG = "SiteBlockerService"
        const val NOTIFICATION_CHANNEL_ID = "site_blocker_channel"
        const val NOTIFICATION_ID = 1002

        const val ACTION_START = "action.START_BLOCKING"
        const val ACTION_STOP = "action.STOP_BLOCKING"

        // Blocked sites list - comprehensive adult/NSFW domains
        val BLOCKED_DOMAINS = setOf(
            // Major porn sites
            "pornhub.com", "www.pornhub.com",
            "xvideos.com", "www.xvideos.com",
            "xnxx.com", "www.xnxx.com",
            "xhamster.com", "www.xhamster.com",
            "youporn.com", "www.youporn.com",
            "spankbang.com", "www.spankbang.com",
            "eporner.com", "www.eporner.com",
            "hqporner.com", "www.hqporner.com",
            "thumbzilla.com", "www.thumbzilla.com",
            "fapster.com", "www.fapster.com",
            "daftsex.com", "www.daftsex.com",
            "motherless.com", "www.motherless.com",
            "tube8.com", "www.tube8.com",
            "keezmovies.com", "www.keezmovies.com",
            "nuvid.com", "www.nuvid.com",
            "upornia.com", "www.upornia.com",
            "anybunny.com", "www.anybunny.com",
            "porzo.com", "www.porzo.com",
            "tubepornstars.com", "www.tubepornstars.com",
            "fux.com", "www.fux.com",
            "maxporn.com", "www.maxporn.com",
            "porn.com", "www.porn.com",
            "redtube.com", "www.redtube.com",
            "youjizz.com", "www.youjizz.com",
            "x videos.com", "www.x videos.com",
            
            // Porn search/aggregators
            "sex.com",
            "pornmd.com",
            "empornium.me",
            
            // Premium porn sites
            "brazzers.com", "www.brazzers.com",
            "bangbros.com", "www.bangbros.com",
            "realitykings.com", "www.realitykings.com",
            "naughtyamerica.com", "www.naughtyamerica.com",
            "digitalplayground.com", "www.digitalplayground.com",
            "mofos.com", "www.mofos.com",
            "twistys.com", "www.twistys.com",
            "babes.com", "www.babes.com",
            "fakehub.com", "www.fakehub.com",
            "castingcouch-x.com", "www.castingcouch-x.com",
            
            // Hentai/Anime
            "nhentai.net", "www.nhentai.net",
            "hanime.tv", "www.hanime.tv",
            "hentai.org", "www.hentai.org",
            "hentaihaven.io", "www.hentaihaven.io",
            "hitomi.la", "www.hitomi.la",
            "rule34.xxx", "www.rule34.xxx",
            "sbubby.com", "www.sbubby.com",
            
            // Cams/OnlyFans
            "onlyfans.com", "www.onlyfans.com",
            "manyvids.com", "www.manyvids.com",
            "myfreecams.com", "www.myfreecams.com",
            "chaturbate.com", "www.chaturbate.com",
            "bongacams.com", "www.bongacams.com",
            "streamate.com", "www.streamate.com",
            "imlive.com", "www.imlive.com",
            "livejasmin.com", "www.livejasmin.com",
            
            // Hookup/Adult dating
            "adultfriendfinder.com", "www.adultfriendfinder.com",
            "aff.com", "www.aff.com",
            "fuckbook.com", "www.fuckbook.com",
            "noStringsAttached.com", "www.noStringsAttached.com",
            
            // Porn GIFs/Images
            "imagefap.com", "www.imagefap.com",
            "imgchili.net", "www.imgchili.net",
            
            // Japanese adult (JAV)
            "javcl.com", "www.javcl.com",
            "tokyohot.com", "www.tokyohot.com",
            "caribbeancom.com", "www.caribbeancom.com",
            "10musume.com", "www.10musume.com",
            "1pondo.com", "www.1pondo.com",
            "pacopacomama.com", "www.pacopacomama.com",
            "gachinco.com", "www.gachinco.com",
            "jav321.com", "www.jav321.com",
            "javfree.com", "www.javfree.com",
            
            // Trackers with adult content
            "sankakucomplex.com", "www.sankakucomplex.com",
            "nyaa.si", "www.nyaa.si",
            "sukebei.com", "www.sukebei.com",
            
            // Other adult
            "ashleymadison.com", "www.ashleymadison.com",
            "playboy.com", "www.playboy.com",
            "penthouse.com", "www.penthouse.com",
            "hustler.com", "www.hustler.com"
        )

        private var vpnInterface: ParcelFileDescriptor? = null
        private var isRunning = false
        private var vpnThread: Thread? = null

        fun start(context: Context) {
            val intent = Intent(context, SiteBlockerService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, SiteBlockerService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        fun isActive(): Boolean = isRunning
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startBlocking()
            ACTION_STOP -> stopBlocking()
        }
        return START_STICKY
    }

    private fun startBlocking() {
        if (isRunning) return

        startForeground(NOTIFICATION_ID, createNotification())

        try {
            // Create VPN interface
            val builder = Builder()
                .setSession("ManWen Site Blocker")
                .addAddress("10.0.0.1", 32)
                .addRoute("0.0.0.0", 0)
                .addDnsServer("8.8.8.8")
                .addDnsServer("8.8.4.4")
                .setMtu(1500)
                .setBlocking(true)

            // Exclude our own app from VPN
            try {
                builder.addDisallowedApplication(this.packageName)
            } catch (e: Exception) {
                Log.w(TAG, "Could not exclude app from VPN", e)
            }

            vpnInterface = builder.establish()
            
            if (vpnInterface != null) {
                isRunning = true
                vpnThread = Thread { runVpnLoop() }.apply { start() }
                Log.i(TAG, "Site blocker VPN started")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start VPN", e)
            stopSelf()
        }
    }

    private fun stopBlocking() {
        isRunning = false
        
        vpnThread?.interrupt()
        vpnThread = null
        
        try {
            vpnInterface?.close()
        } catch (e: Exception) {
            Log.w(TAG, "Error closing VPN", e)
        }
        vpnInterface = null
        
        stopForeground(true)
        stopSelf()
        Log.i(TAG, "Site blocker stopped")
    }

    private fun runVpnLoop() {
        val vpnFd = vpnInterface ?: return
        
        try {
            val inputStream = FileInputStream(vpnFd.fileDescriptor)
            val outputStream = FileOutputStream(vpnFd.fileDescriptor)
            val packet = ByteBuffer.allocate(32767)
            
            while (isRunning && !Thread.currentThread().isInterrupted) {
                try {
                    packet.clear()
                    val length = inputStream.read(packet.array())
                    
                    if (length > 0) {
                        packet.limit(length)
                        processPacket(packet, outputStream)
                    }
                } catch (e: Exception) {
                    if (isRunning) {
                        Log.w(TAG, "VPN loop error", e)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "VPN loop fatal error", e)
        }
    }

    private fun processPacket(packet: ByteBuffer, outputStream: FileOutputStream) {
        packet.order(ByteOrder.BIG_ENDIAN)
        
        val version = (packet.get(0).toInt() shr 4) and 0xF
        if (version != 4) return // Only handle IPv4 for now
        
        val protocol = packet.get(9).toInt() and 0xFF
        
        // Extract destination IP
        val destIp = "${packet.get(16).toInt() and 0xFF}." +
                     "${packet.get(17).toInt() and 0xFF}." +
                     "${packet.get(18).toInt() and 0xFF}." +
                     "${packet.get(19).toInt() and 0xFF}"
        
        // For DNS (UDP port 53), check the domain being queried
        if (protocol == 17) { // UDP
            val destPort = ((packet.get(20).toInt() and 0xFF) shl 8) or 
                          (packet.get(21).toInt() and 0xFF)
            
            if (destPort == 53) {
                val packetLen = packet.limit()
                // Try to extract domain from DNS query
                val domain = extractDnsDomain(packet, packetLen)
                if (domain != null && isDomainBlocked(domain)) {
                    Log.i(TAG, "Blocking: $domain")
                    // Send blocking response or just drop
                    return
                }
            }
        }
        
        // Forward packet normally
        packet.position(0)
        outputStream.write(packet.array(), 0, packet.limit())
    }

    private fun extractDnsDomain(packet: ByteBuffer, length: Int): String? {
        // DNS header is 12 bytes, then query starts
        if (length < 28) return null
        
        try {
            val dnsData = packet.array()
            val offset = 28 // Skip IP + UDP header
            
            // Skip past the query name - find the null terminator
            var pos = offset
            while (pos < length && dnsData[pos] != 0.toByte()) {
                pos++
            }
            pos++ // Skip null byte
            
            // Now at query type (2 bytes) and class (2 bytes)
            if (pos + 4 > length) return null
            
            // Extract domain from the packet (simplified parsing)
            val domainBuilder = StringBuilder()
            var dotPos = offset + 1
            while (dotPos < pos && dotPos < length) {
                val labelLen = dnsData[dotPos - 1].toInt() and 0xFF
                if (labelLen == 0) break
                if (domainBuilder.isNotEmpty()) domainBuilder.append(".")
                for (i in 0 until labelLen) {
                    domainBuilder.append(dnsData[dotPos + i].toChar())
                }
                dotPos += labelLen + 1
            }
            
            return if (domainBuilder.isNotEmpty()) domainBuilder.toString() else null
        } catch (e: Exception) {
            return null
        }
    }

    private fun isDomainBlocked(domain: String): Boolean {
        val lowerDomain = domain.lowercase()
        
        for (blocked in BLOCKED_DOMAINS) {
            if (lowerDomain == blocked || 
                lowerDomain.endsWith(".$blocked") ||
                lowerDomain == "www.$blocked") {
                return true
            }
        }
        return false
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Site Blocker",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Blocking adult and NSFW content"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Man Wen Site Blocker Active")
            .setContentText("Blocking adult content sites")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopBlocking()
    }
}