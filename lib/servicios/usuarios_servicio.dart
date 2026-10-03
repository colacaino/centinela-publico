import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/modelos.dart';

class UsuariosServicio {
  UsuariosServicio({FirebaseFirestore? firestore, FirebaseFunctions? functions})
    : _db = firestore ?? FirebaseFirestore.instance,
      _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  Stream<List<Usuario>> listaUsuarios(String siteId) => _db
      .collection('usuarios')
      .where('sedeId', isEqualTo: siteId)
      .orderBy('nombre')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Usuario.desdeDoc(doc.id, doc.data()))
            .toList(),
      );

  Future<void> crearUsuario({
    required String nombre,
    required String correo,
    required String temporaryPassword,
    required String role,
  }) async {
    await _functions.httpsCallable('crearUsuarioV2').call({
      'nombre': nombre,
      'email': correo,
      'temporaryPassword': temporaryPassword,
      'role': role,
    });
  }

  Future<void> actualizarUsuario({
    required String uid,
    required String nombre,
    required String role,
  }) async {
    await _functions.httpsCallable('actualizarUsuarioV2').call({
      'uid': uid,
      'nombre': nombre,
      'role': role,
    });
  }

  Future<void> establecerActivo(String uid, bool active) async {
    await _functions.httpsCallable('establecerUsuarioActivoV2').call({
      'uid': uid,
      'active': active,
    });
  }

  Future<void> eliminarUsuario(String uid) async {
    await _functions.httpsCallable('eliminarUsuarioV2').call({
      'uid': uid,
      'confirmUid': uid,
    });
  }
}
