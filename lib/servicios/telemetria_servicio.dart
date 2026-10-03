import 'package:shared_preferences/shared_preferences.dart';

/// Tiempos capturados por el cliente para correlacionarlos con los tiempos del
/// backend. Son diagnósticos (el reloj del teléfono no es una fuente confiable
/// de autorización) y se adjuntan al evento de ACK.
class TelemetriaServicio {
  TelemetriaServicio._();
  static final instancia = TelemetriaServicio._();

  String _key(String incidentId, String phase) =>
      'centinela_timing_${phase}_$incidentId';

  Future<void> registrarRecepcion(String incidentId) =>
      _registrarPrimero(incidentId, 'received');

  Future<void> registrarNotificacionPresentada(String incidentId) =>
      _registrarPrimero(incidentId, 'notification_presented');

  Future<void> registrarAlarmaPresentada(String incidentId) =>
      _registrarPrimero(incidentId, 'alarm_presented');

  Future<void> _registrarPrimero(String incidentId, String phase) async {
    if (incidentId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    final key = _key(incidentId, phase);
    if (!preferences.containsKey(key)) {
      await preferences.setInt(key, DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<Map<String, Object>> paraAck(
    String incidentId, {
    required String installationId,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final result = <String, Object>{'installationId': installationId};
    final received = preferences.getInt(_key(incidentId, 'received'));
    final notification = preferences.getInt(
      _key(incidentId, 'notification_presented'),
    );
    final alarm = preferences.getInt(_key(incidentId, 'alarm_presented'));
    if (received != null) result['receivedAtMillis'] = received;
    if (notification != null) {
      result['notificationPresentedAtMillis'] = notification;
    }
    if (alarm != null) result['alarmPresentedAtMillis'] = alarm;
    return result;
  }
}
