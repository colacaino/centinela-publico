import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/colores.dart';
import '../servicios/auth_servicio.dart';

// ===== Pantalla de Login (correo + contraseña) =====
class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final AuthServicio _auth = AuthServicio();
  final _correoCtrl = TextEditingController();
  final _contrasenaCtrl = TextEditingController();

  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correoCtrl.dispose();
    _contrasenaCtrl.dispose();
    super.dispose();
  }

  // Intenta iniciar sesión con las credenciales ingresadas.
  Future<void> _ingresar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await _auth.iniciarSesion(_correoCtrl.text, _contrasenaCtrl.text);
      // No navegamos manualmente: el AuthGate detecta el cambio de sesión
      // y redirige automáticamente según el rol.
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mensajeError(e.code));
    } catch (e) {
      setState(() => _error = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // Traduce los códigos de error de Firebase a mensajes en español.
  String _mensajeError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      default:
        return 'No se pudo iniciar sesión ($code).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colores.fondo,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Encabezado / logo de texto
              const Icon(Icons.shield, size: 72, color: Colores.rojo),
              const SizedBox(height: 8),
              const Text(
                'CENTINELA',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                  color: Colores.rojo,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sistema de alertas escolares',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 40),

              // Campo de correo
              TextField(
                controller: _correoCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Campo de contraseña
              TextField(
                controller: _contrasenaCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),

              // Mensaje de error (si hay)
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colores.rojo),
                  ),
                ),
              const SizedBox(height: 16),

              // Botón de ingreso
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _ingresar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.rojo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _cargando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'INGRESAR',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
