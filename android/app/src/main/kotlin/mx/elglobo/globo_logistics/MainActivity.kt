package mx.elglobo.globo_logistics

import android.app.NotificationChannel
import android.app.NotificationManager
import android.graphics.Color
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerSosNotificationChannel()
    }

    private fun registerSosNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager

        // Canal de emergencias SOS — máxima prioridad, sonido personalizado
        val channel = NotificationChannel(
            "sos_alerts",
            "Alertas SOS",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Canal de emergencias para el Protocolo SOS"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 250, 100, 250, 100, 250)
            enableLights(true)
            lightColor = Color.RED
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC

            // Sonido personalizado (res/raw/sos_alarm.mp3).
            // Si el archivo no existe, Android usa el sonido de notificación por defecto.
            val soundUri = Uri.parse(
                "android.resource://${packageName}/raw/sos_alarm"
            )
            val audioAttrs = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            setSound(soundUri, audioAttrs)
        }

        manager.createNotificationChannel(channel)
    }
}
