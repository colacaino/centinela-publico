import 'package:flutter/material.dart';
import '../core/colores.dart';
import '../core/modelos.dart';
import '../core/roles.dart';
import '../servicios/auth_servicio.dart';
import '../servicios/incidentes_servicio.dart';
import 'diagnostico_pantalla.dart';

class MonitoreoPantalla extends StatelessWidget {
  const MonitoreoPantalla({super.key, required this.usuario});
  final Usuario usuario;

  @override
  Widget build(BuildContext context) {
    final auth = AuthServicio();
    final incidents = IncidentesServicio();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colores.rojo,
        foregroundColor: Colors.white,
        title: Text('CENTINELA · ${Roles.etiqueta(usuario.role)}'),
        actions: [
          IconButton(
            tooltip: 'Diagnóstico',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DiagnosticoPantalla(usuario: usuario),
              ),
            ),
            icon: const Icon(Icons.health_and_safety_outlined),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: auth.cerrarSesion,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<Incidente>>(
        stream: incidents.paraReceptor(usuario),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se pudo consultar. Verifica claims, índices y conexión.',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final values = snapshot.data!;
          if (values.isEmpty) {
            return const Center(
              child: Text('No hay incidentes visibles para este rol.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: values.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final incident = values[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colores.porNivel(incident.nivel),
                    foregroundColor: Colors.white,
                    child: Text(
                      incident.nivel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    '${incident.simulacro ? 'SIMULACRO · ' : ''}${incident.etiqueta}',
                  ),
                  subtitle: Text(
                    '${incident.salaNombre}\n${incident.nombreEmisor} · ${incident.horaTexto}\nEstado: ${incident.estado.etiqueta}',
                  ),
                  isThreeLine: true,
                  trailing: _IncidentAction(
                    incident: incident,
                    service: incidents,
                    user: usuario,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _IncidentAction extends StatefulWidget {
  const _IncidentAction({
    required this.incident,
    required this.service,
    required this.user,
  });
  final Incidente incident;
  final IncidentesServicio service;
  final Usuario user;
  @override
  State<_IncidentAction> createState() => _IncidentActionState();
}

class _IncidentActionState extends State<_IncidentAction> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() operation) async {
    setState(() => _busy = true);
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La operación no fue aceptada; el estado pudo cambiar.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if ([
          EstadoIncidente.created,
          EstadoIncidente.notified,
        ].contains(widget.incident.estado) &&
        widget.incident.vigente) {
      return IconButton(
        tooltip: 'Reconocer',
        onPressed: () =>
            _run(() => widget.service.reconocer(widget.incident.id)),
        icon: const Icon(Icons.pan_tool_alt, color: Colores.rojo),
      );
    }
    if (widget.incident.estado == EstadoIncidente.acknowledged &&
        (widget.incident.acknowledgedBy == widget.user.uid ||
            widget.user.role == Roles.admin)) {
      return IconButton(
        tooltip: 'Marcar resuelto',
        onPressed: () =>
            _run(() => widget.service.resolver(widget.incident.id)),
        icon: const Icon(Icons.check_circle_outline, color: Colors.green),
      );
    }
    return const SizedBox.shrink();
  }
}
