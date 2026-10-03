import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../core/modelos.dart';
import '../servicios/auth_servicio.dart';

class CambioContrasenaPantalla extends StatefulWidget {
  const CambioContrasenaPantalla({super.key, required this.usuario});
  final Usuario usuario;
  @override
  State<CambioContrasenaPantalla> createState() =>
      _CambioContrasenaPantallaState();
}

class _CambioContrasenaPantallaState extends State<CambioContrasenaPantalla> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    final value = _first.text;
    if (value != _second.text ||
        value.length < 12 ||
        !RegExp('[a-z]').hasMatch(value) ||
        !RegExp('[A-Z]').hasMatch(value) ||
        !RegExp('[0-9]').hasMatch(value)) {
      setState(
        () => _error =
            'Usa 12+ caracteres, mayúscula, minúscula y número; ambas entradas deben coincidir.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('cambiarContrasenaInicialV2')
          .call({'newPassword': value});
      await AuthServicio().cerrarSesion();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No fue posible cambiarla. Verifica la conexión e inténtalo nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.password, size: 64),
              const SizedBox(height: 12),
              Text(
                'Cambia tu contraseña temporal',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Hola, ${widget.usuario.nombre}. Debes completar este paso antes de usar CENTINELA.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _first,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _second,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Repetir contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _change,
                child: _busy
                    ? const CircularProgressIndicator()
                    : const Text('CAMBIAR Y VOLVER A INGRESAR'),
              ),
              TextButton(
                onPressed: _busy ? null : AuthServicio().cerrarSesion,
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
