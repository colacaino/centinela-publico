import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/colores.dart';
import '../core/modelos.dart';
import '../core/roles.dart';
import '../servicios/auth_servicio.dart';
import '../widgets/receptor_listener.dart';
import 'admin_pantalla.dart';
import 'cambio_contrasena_pantalla.dart';
import 'docente_pantalla.dart';
import 'login_pantalla.dart';
import 'monitoreo_pantalla.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthServicio();
    return StreamBuilder<User?>(
      stream: auth.cambiosDeSesion,
      builder: (context, session) {
        if (session.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = session.data;
        if (user == null) return const LoginPantalla();
        return FutureBuilder<Usuario?>(
          future: auth.obtenerPerfil(user.uid),
          builder: (context, profile) {
            if (profile.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            if (profile.hasError) {
              return _AccessError(
                auth: auth,
                message:
                    'No fue posible validar el perfil. Revisa la conexión.',
              );
            }
            final value = profile.data;
            if (value == null) {
              return _AccessError(
                auth: auth,
                message:
                    'La cuenta no posee un perfil v2 activo. Contacta al administrador.',
              );
            }
            if (value.mustChangePassword) {
              return CambioContrasenaPantalla(usuario: value);
            }
            switch (value.role) {
              case Roles.docente:
                return DocentePantalla(usuario: value);
              case Roles.admin:
                return ReceptorListener(
                  usuario: value,
                  child: AdminPantalla(usuario: value),
                );
              case Roles.inspector:
              case Roles.direccion:
                return ReceptorListener(
                  usuario: value,
                  child: MonitoreoPantalla(usuario: value),
                );
              default:
                return _AccessError(
                  auth: auth,
                  message: 'El rol recibido no es reconocido por esta versión.',
                );
            }
          },
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator(color: Colores.rojo)),
  );
}

class _AccessError extends StatelessWidget {
  const _AccessError({required this.auth, required this.message});
  final AuthServicio auth;
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gpp_bad_outlined, size: 64, color: Colores.rojo),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.cerrarSesion,
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    ),
  );
}
