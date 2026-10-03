import 'package:centinela/core/modelos.dart';
import 'package:centinela/core/notificacion_utils.dart';
import 'package:centinela/core/roles.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('los estados terminales e intermedios quedan diferenciados', () {
    expect(EstadoIncidente.desde('ACKNOWLEDGED'), EstadoIncidente.acknowledged);
    expect(EstadoIncidente.resolved.terminal, isTrue);
    expect(EstadoIncidente.cancelled.terminal, isTrue);
    expect(EstadoIncidente.notified.terminal, isFalse);
    expect(EstadoIncidente.desde('DESCONOCIDO'), EstadoIncidente.expired);
  });

  test('la matriz visual coincide con los niveles autorizados', () {
    expect(Roles.nivelesParaRol(Roles.inspector), ['1', '2', '3']);
    expect(Roles.nivelesParaRol(Roles.direccion), ['2', '3']);
    expect(Roles.nivelesParaRol(Roles.docente), isEmpty);
    expect(Roles.recibeNivel(Roles.direccion, '1'), isFalse);
    expect(Roles.recibeNivel(Roles.admin, '1'), isTrue);
  });

  test('el modelo de usuario exige los campos v2 activos', () {
    final user = Usuario.desdeDoc('uid-1', {
      'nombre': 'Ana',
      'email': 'ana@example.com',
      'role': 'docente',
      'sedeId': 'site-a',
      'active': true,
      'mustChangePassword': false,
    });
    expect(user.uid, 'uid-1');
    expect(user.role, 'docente');
    expect(user.sedeId, 'site-a');
    expect(user.active, isTrue);
    expect(user.mustChangePassword, isFalse);
  });

  test('un push vencido o terminal nunca se considera vigente', () {
    final now = DateTime.fromMillisecondsSinceEpoch(2_000_000);
    final valid = {
      'schemaVersion': '2',
      'incidentId': 'inc_123',
      'createdAtMillis': '1000000',
      'expiresAtMillis': '3000000',
      'estado': 'NOTIFIED',
    };
    expect(pushVigente(valid, now: now), isTrue);
    expect(
      pushVigente({...valid, 'expiresAtMillis': '1500000'}, now: now),
      isFalse,
    );
    expect(pushVigente({...valid, 'estado': 'CANCELLED'}, now: now), isFalse);
    expect(notificationId('inc_123'), notificationId('inc_123'));
    expect(notificationId('inc_123'), isNot(notificationId('inc_124')));
  });
}
