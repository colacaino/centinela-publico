import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoIncidente {
  created,
  notified,
  acknowledged,
  resolved,
  cancelled,
  expired;

  static EstadoIncidente desde(String value) {
    return EstadoIncidente.values.firstWhere(
      (state) => state.name.toUpperCase() == value.toUpperCase(),
      orElse: () => EstadoIncidente.expired,
    );
  }

  String get firestore => name.toUpperCase();

  bool get terminal =>
      this == EstadoIncidente.resolved ||
      this == EstadoIncidente.cancelled ||
      this == EstadoIncidente.expired;

  String get etiqueta {
    switch (this) {
      case EstadoIncidente.created:
        return 'Creado';
      case EstadoIncidente.notified:
        return 'Notificado';
      case EstadoIncidente.acknowledged:
        return 'Reconocido';
      case EstadoIncidente.resolved:
        return 'Resuelto';
      case EstadoIncidente.cancelled:
        return 'Cancelado';
      case EstadoIncidente.expired:
        return 'Expirado';
    }
  }
}

class Usuario {
  final String uid;
  final String nombre;
  final String correo;
  final String role;
  final String sedeId;
  final bool active;
  final bool mustChangePassword;

  const Usuario({
    required this.uid,
    required this.nombre,
    required this.correo,
    required this.role,
    required this.sedeId,
    required this.active,
    required this.mustChangePassword,
  });

  factory Usuario.desdeDoc(String uid, Map<String, dynamic> data) {
    return Usuario(
      uid: uid,
      nombre: (data['nombre'] ?? data['email'] ?? 'Usuario').toString(),
      correo: (data['email'] ?? data['correo'] ?? '').toString(),
      role: (data['role'] ?? data['rol'] ?? '').toString(),
      sedeId: (data['sedeId'] ?? '').toString(),
      active: data['active'] == true,
      mustChangePassword: data['mustChangePassword'] == true,
    );
  }

  String get rol => role;
  String get sede => sedeId;
}

class Sala {
  final String id;
  final String nombre;
  final bool active;

  const Sala({required this.id, required this.nombre, required this.active});

  factory Sala.desdeDoc(String id, Map<String, dynamic> data) => Sala(
    id: id,
    nombre: (data['nombre'] ?? id).toString(),
    active: data['active'] != false,
  );
}

class Incidente {
  final String id;
  final int schemaVersion;
  final String nivel;
  final String etiqueta;
  final String sedeId;
  final String? salaId;
  final String salaNombre;
  final String? emisorUid;
  final String nombreEmisor;
  final String origen;
  final bool simulacro;
  final EstadoIncidente estado;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? acknowledgedBy;
  final String? acknowledgedByName;
  final DateTime? acknowledgedAt;

  const Incidente({
    required this.id,
    required this.schemaVersion,
    required this.nivel,
    required this.etiqueta,
    required this.sedeId,
    required this.salaId,
    required this.salaNombre,
    required this.emisorUid,
    required this.nombreEmisor,
    required this.origen,
    required this.simulacro,
    required this.estado,
    required this.createdAt,
    required this.expiresAt,
    required this.acknowledgedBy,
    required this.acknowledgedByName,
    required this.acknowledgedAt,
  });

  factory Incidente.desdeDoc(String id, Map<String, dynamic> data) {
    DateTime date(dynamic value, {DateTime? fallback}) => value is Timestamp
        ? value.toDate()
        : fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
    return Incidente(
      id: id,
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 0,
      nivel: (data['nivel'] ?? '').toString(),
      etiqueta: (data['etiqueta'] ?? 'Alerta').toString(),
      sedeId: (data['sedeId'] ?? '').toString(),
      salaId: data['salaId']?.toString(),
      salaNombre: (data['salaNombreSnapshot'] ?? 'Ubicación no especificada')
          .toString(),
      emisorUid: data['emisorUid']?.toString(),
      nombreEmisor: (data['nombreEmisorSnapshot'] ?? 'CENTINELA').toString(),
      origen: (data['origen'] ?? 'desconocido').toString(),
      simulacro: data['simulacro'] == true,
      estado: EstadoIncidente.desde((data['estado'] ?? 'EXPIRED').toString()),
      createdAt: date(data['createdAt']),
      expiresAt: date(data['expiresAt']),
      acknowledgedBy: data['acknowledgedBy']?.toString(),
      acknowledgedByName: data['acknowledgedByName']?.toString(),
      acknowledgedAt: data['acknowledgedAt'] is Timestamp
          ? (data['acknowledgedAt'] as Timestamp).toDate()
          : null,
    );
  }

  bool get vigente =>
      schemaVersion == 2 &&
      DateTime.now().isBefore(expiresAt) &&
      !estado.terminal;

  String get horaTexto {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(createdAt.hour)}:${two(createdAt.minute)}:${two(createdAt.second)}';
  }
}
