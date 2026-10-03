import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/modelos.dart';
import '../core/roles.dart';
import 'instalaciones_servicio.dart';
import 'telemetria_servicio.dart';

class IncidentesServicio {
  IncidentesServicio({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Future<String> crear({
    required String nivel,
    required String idempotencyKey,
    String? salaId,
    bool simulacro = false,
  }) async {
    final result = await _functions.httpsCallable('crearIncidenteV2').call({
      'nivel': nivel,
      'salaId': salaId,
      'simulacro': simulacro,
      'idempotencyKey': idempotencyKey,
    });
    return Map<String, dynamic>.from(
      result.data as Map,
    )['incidentId'].toString();
  }

  Future<void> reconocer(String incidentId) async {
    final installationId = await InstalacionesServicio.instancia.installationId;
    await _functions.httpsCallable('reconocerIncidenteV2').call({
      'incidentId': incidentId,
      'telemetry': await TelemetriaServicio.instancia.paraAck(
        incidentId,
        installationId: installationId,
      ),
    });
  }

  Future<void> resolver(String incidentId) async {
    await _functions.httpsCallable('resolverIncidenteV2').call({
      'incidentId': incidentId,
    });
  }

  Future<void> cancelar(String incidentId, String reason) async {
    await _functions.httpsCallable('cancelarIncidenteV2').call({
      'incidentId': incidentId,
      'reason': reason,
    });
  }

  Stream<Incidente?> observar(String incidentId) => _db
      .collection('incidentes')
      .doc(incidentId)
      .snapshots()
      .map(
        (doc) => doc.exists && doc.data() != null
            ? Incidente.desdeDoc(doc.id, doc.data()!)
            : null,
      );

  Future<Incidente?> obtenerVigente(String incidentId) async {
    if (incidentId.isEmpty) return null;
    final doc = await _db.collection('incidentes').doc(incidentId).get();
    if (!doc.exists || doc.data() == null) return null;
    final incident = Incidente.desdeDoc(doc.id, doc.data()!);
    return incident.vigente ? incident : null;
  }

  Stream<List<Incidente>> paraReceptor(Usuario user) {
    final levels = Roles.nivelesParaRol(user.role);
    if (levels.isEmpty) return Stream.value(const []);
    return _db
        .collection('incidentes')
        .where('sedeId', isEqualTo: user.sedeId)
        .where('nivel', whereIn: levels)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Incidente.desdeDoc(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<Incidente>> emitidosPor(Usuario user) => _db
      .collection('incidentes')
      .where('sedeId', isEqualTo: user.sedeId)
      .where('emisorUid', isEqualTo: user.uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Incidente.desdeDoc(doc.id, doc.data()))
            .toList(),
      );

  Stream<List<Sala>> salas(String siteId) => _db
      .collection('sedes')
      .doc(siteId)
      .collection('salas')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((snapshot) {
        final result = snapshot.docs
            .map((doc) => Sala.desdeDoc(doc.id, doc.data()))
            .toList();
        result.sort((a, b) => a.nombre.compareTo(b.nombre));
        return result;
      });
}
