import 'package:flutter/services.dart';

// ===== Control del volumen del stream de ALARMA (Android) =====
// Habla con código nativo Kotlin (AudioManager.STREAM_ALARM) a través de un
// MethodChannel. Se usa el stream de ALARMA porque es el mismo por el que
// suena la alerta (AndroidUsageType.alarm en alerta_fullscreen.dart).
//
// Se usa para forzar el volumen de alarma al máximo mientras la alerta está
// activa y restaurarlo al valor original cuando el usuario la atiende.
class VolumenAlarma {
  // Debe coincidir con el nombre del canal definido en MainActivity.kt.
  static const MethodChannel _canal = MethodChannel('centinela/volumen_alarma');

  // Devuelve el volumen actual del stream de alarma (0..máximo).
  static Future<int> obtenerVolumen() async {
    try {
      final v = await _canal.invokeMethod<int>('getAlarmVolume');
      return v ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // Devuelve el volumen MÁXIMO posible del stream de alarma.
  static Future<int> obtenerVolumenMaximo() async {
    try {
      final v = await _canal.invokeMethod<int>('getAlarmMaxVolume');
      return v ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // Fija el volumen del stream de alarma a un valor concreto.
  static Future<void> fijarVolumen(int volumen) async {
    try {
      await _canal.invokeMethod('setAlarmVolume', {'volume': volumen});
    } catch (_) {
      // Si el dispositivo no permite el cambio (p. ej. ciertas políticas de
      // No molestar), se ignora silenciosamente: la alerta sigue sonando.
    }
  }
}
