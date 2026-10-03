import 'package:flutter/services.dart';

class PermisosServicio {
  static const MethodChannel _channel = MethodChannel('centinela/permisos');

  static Future<bool> _boolean(String method) async {
    try {
      return (await _channel.invokeMethod<bool>(method)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> puedeFullScreen() => _boolean('puedeFullScreen');
  static Future<bool> ignoraOptimizacionBateria() => _boolean('ignoraBateria');

  // Solo se abre por acción explícita desde Diagnóstico; nunca al iniciar.
  static Future<void> abrirAjusteFullScreen() async {
    try {
      await _channel.invokeMethod('pedirFullScreen');
    } catch (_) {}
  }
}
