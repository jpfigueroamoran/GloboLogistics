// Implementación web mediante dart:js_interop (Dart 3.1+).
// Solo se compila cuando dart.library.html está disponible (plataforma web).
// Las funciones JS globoPlaySosAlarm / globoStopSosAlarm están definidas en web/index.html.
import 'dart:js_interop';

@JS('globoPlaySosAlarm')
external void _jsPlay();

@JS('globoStopSosAlarm')
external void _jsStop();

void playAlarm() => _jsPlay();
void stopAlarm() => _jsStop();
