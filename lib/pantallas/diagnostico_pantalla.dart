import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/modelos.dart';
import '../servicios/instalaciones_servicio.dart';
import '../servicios/notificaciones_servicio.dart';
import '../servicios/permisos_servicio.dart';

class DiagnosticoPantalla extends StatefulWidget {
  const DiagnosticoPantalla({super.key, required this.usuario});
  final Usuario usuario;
  @override
  State<DiagnosticoPantalla> createState() => _DiagnosticoPantallaState();
}

class _DiagnosticoPantallaState extends State<DiagnosticoPantalla> {
  Future<List<_Check>>? _checks;

  @override
  void initState() {
    super.initState();
    _checks = _load();
  }

  Future<List<_Check>> _load() async {
    final package = await PackageInfo.fromPlatform();
    final tokenResult = await FirebaseAuth.instance.currentUser
        ?.getIdTokenResult();
    final claims = tokenResult?.claims ?? const <String, dynamic>{};
    String firestore = 'Sin conexión';
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.usuario.uid)
          .get(const GetOptions(source: Source.server));
      firestore = 'Conectado y autorizado';
    } catch (_) {}
    String appCheck = 'No disponible';
    try {
      appCheck =
          (await FirebaseAppCheck.instance.getToken(false))?.isNotEmpty == true
          ? 'Token presente'
          : 'Sin token';
    } catch (_) {}
    final fcm = await FirebaseMessaging.instance.getToken();
    return [
      _Check('Versión', '${package.version}+${package.buildNumber}', true),
      _Check('Android', Platform.operatingSystemVersion, true),
      _Check(
        'Cuenta activa',
        FirebaseAuth.instance.currentUser != null ? 'Sí' : 'No',
        FirebaseAuth.instance.currentUser != null,
      ),
      _Check(
        'Claims',
        '${claims['role'] ?? 'sin rol'} · ${claims['sedeId'] ?? 'sin sede'} · active=${claims['active']}',
        claims['active'] == true,
      ),
      _Check(
        'Perfil',
        '${widget.usuario.role} · ${widget.usuario.sedeId}',
        widget.usuario.active,
      ),
      _Check('Firestore', firestore, firestore.startsWith('Conectado')),
      _Check('App Check', appCheck, appCheck == 'Token presente'),
      _Check(
        'FCM',
        fcm?.isNotEmpty == true
            ? 'Token presente (no se muestra)'
            : 'Sin token',
        fcm?.isNotEmpty == true,
      ),
      _Check(
        'Instalación',
        '${(await InstalacionesServicio.instancia.installationId).substring(0, 12)}…',
        true,
      ),
      _Check(
        'Notificaciones',
        await NotificacionesServicio.instancia.notificacionesHabilitadas()
            ? 'Habilitadas'
            : 'Deshabilitadas',
        await NotificacionesServicio.instancia.notificacionesHabilitadas(),
      ),
      _Check(
        'Pantalla completa',
        await PermisosServicio.puedeFullScreen()
            ? 'Permitida'
            : 'Requiere ajuste del usuario',
        await PermisosServicio.puedeFullScreen(),
      ),
      _Check(
        'Optimización de batería',
        await PermisosServicio.ignoraOptimizacionBateria()
            ? 'Exenta por decisión del usuario/sistema'
            : 'Activa (estado normal)',
        true,
      ),
    ];
  }

  void _refresh() => setState(() => _checks = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Diagnóstico operativo'),
      actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ],
    ),
    body: FutureBuilder<List<_Check>>(
      future: _checks,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Esta pantalla comprueba configuración; no demuestra entrega garantizada de FCM ni reemplaza una prueba física.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...snapshot.data!.map(
              (check) => Card(
                child: ListTile(
                  leading: Icon(
                    check.ok ? Icons.check_circle : Icons.warning_amber,
                    color: check.ok ? Colors.green : Colors.orange,
                  ),
                  title: Text(check.name),
                  subtitle: Text(check.value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await FirebaseMessaging.instance.requestPermission(
                  alert: true,
                  badge: true,
                  sound: true,
                );
                _refresh();
              },
              icon: const Icon(Icons.notifications),
              label: const Text('Solicitar permiso de notificaciones'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await PermisosServicio.abrirAjusteFullScreen();
              },
              icon: const Icon(Icons.fullscreen),
              label: const Text('Abrir ajuste de pantalla completa'),
            ),
          ],
        );
      },
    ),
  );
}

class _Check {
  const _Check(this.name, this.value, this.ok);
  final String name;
  final String value;
  final bool ok;
}
