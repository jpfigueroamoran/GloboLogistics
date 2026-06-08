// Importación condicional: web usa dart:js para tocar la sirena Web Audio API;
// nativo usa el stub (FCM gestiona el sonido de notificación en background).
import '_sos_audio_impl.dart'
    if (dart.library.html) '_sos_audio_web_impl.dart';

/// Reproduce / detiene la alarma de emergencia SOS en primer plano.
///
/// En web genera una sirena sintetizada con Web Audio API.
/// En móvil, el canal FCM "sos_alerts" maneja el sonido en background;
/// para foreground, este servicio se puede extender con audioplayers si se requiere.
class SosAudioService {
  SosAudioService._();

  static void play() => playAlarm();
  static void stop() => stopAlarm();
}
