import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/modelos.dart';
import 'instalaciones_servicio.dart';

class AuthServicio {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get cambiosDeSesion => _auth.idTokenChanges();
  User? get usuarioActual => _auth.currentUser;

  Future<void> iniciarSesion(String correo, String contrasena) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: correo.trim(),
      password: contrasena,
    );
    final token = await credential.user!.getIdTokenResult(true);
    final claims = token.claims ?? const <String, dynamic>{};
    if (claims['active'] != true ||
        !const [
          'docente',
          'inspector',
          'direccion',
          'admin',
        ].contains(claims['role']) ||
        (claims['sedeId']?.toString().isEmpty ?? true)) {
      await _auth.signOut();
      throw StateError(
        'La cuenta no tiene claims v2 activos. Contacta al administrador.',
      );
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await InstalacionesServicio.instancia.desactivarActual();
    } finally {
      await _auth.signOut();
    }
  }

  Future<Usuario?> obtenerPerfil(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    final profile = Usuario.desdeDoc(uid, doc.data()!);
    if (!profile.active || profile.sedeId.isEmpty || profile.role.isEmpty) {
      return null;
    }
    return profile;
  }
}
