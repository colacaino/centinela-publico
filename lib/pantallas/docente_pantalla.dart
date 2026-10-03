import 'package:flutter/material.dart';
import '../core/colores.dart';
import '../core/modelos.dart';
import '../servicios/auth_servicio.dart';
import '../servicios/incidentes_servicio.dart';
import '../widgets/boton_alerta.dart';
import 'diagnostico_pantalla.dart';

class DocentePantalla extends StatefulWidget {
  const DocentePantalla({super.key, required this.usuario});
  final Usuario usuario;

  @override
  State<DocentePantalla> createState() => _DocentePantallaState();
}

class _DocentePantallaState extends State<DocentePantalla> {
  final _incidents = IncidentesServicio();
  final _auth = AuthServicio();
  String? _roomId;
  bool _drill = false;
  bool _sending = false;
  String _status = 'Sistema listo';

  Future<void> _send(String level, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_drill ? 'Confirmar simulacro' : 'Confirmar emergencia'),
        content: Text(
          '$label · Nivel $level\n\nUbicación: ${_roomId ?? 'No especificada'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ENVIAR'),
          ),
        ],
      ),
    );
    if (confirmed != true || _sending) return;
    setState(() {
      _sending = true;
      _status = 'Enviando…';
    });
    try {
      final key =
          '${widget.usuario.uid}:${DateTime.now().microsecondsSinceEpoch}';
      final id = await _incidents.crear(
        nivel: level,
        salaId: _roomId,
        simulacro: _drill,
        idempotencyKey: key,
      );
      if (mounted) {
        setState(() => _status = 'Incidente creado: ${id.substring(0, 12)}…');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'No se pudo enviar. Verifica red, sesión y configuración.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colores.rojo,
      foregroundColor: Colors.white,
      title: const Text(
        'CENTINELA',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
      actions: [
        IconButton(
          tooltip: 'Diagnóstico',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DiagnosticoPantalla(usuario: widget.usuario),
            ),
          ),
          icon: const Icon(Icons.health_and_safety_outlined),
        ),
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: _auth.cerrarSesion,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hola, ${widget.usuario.nombre}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          'Sede: ${widget.usuario.sedeId}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Sala>>(
          stream: _incidents.salas(widget.usuario.sedeId),
          builder: (context, snapshot) {
            final rooms = snapshot.data ?? const <Sala>[];
            if (_roomId != null && !rooms.any((room) => room.id == _roomId)) {
              _roomId = null;
            }
            return DropdownButtonFormField<String?>(
              initialValue: _roomId,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin ubicación configurada'),
                ),
                ...rooms.map(
                  (room) => DropdownMenuItem<String?>(
                    value: room.id,
                    child: Text(room.nombre),
                  ),
                ),
              ],
              onChanged: _sending
                  ? null
                  : (value) => setState(() => _roomId = value),
            );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _drill,
          onChanged: _sending
              ? null
              : (value) => setState(() => _drill = value),
          title: const Text('Modo simulacro'),
          subtitle: const Text(
            'La alerta quedará marcada visiblemente como prueba.',
          ),
        ),
        const SizedBox(height: 8),
        BotonAlerta(
          color: Colores.amarillo,
          titulo: 'EMERGENCIA MÉDICA',
          subtitulo: 'Nivel 1 · Amarillo',
          onTap: _sending ? null : () => _send('1', 'Emergencia médica'),
        ),
        const SizedBox(height: 12),
        BotonAlerta(
          color: Colores.naranjo,
          titulo: 'RIÑA O INTRUSO',
          subtitulo: 'Nivel 2 · Naranjo',
          onTap: _sending ? null : () => _send('2', 'Riña o intruso'),
        ),
        const SizedBox(height: 12),
        BotonAlerta(
          color: Colores.rojo,
          titulo: 'ARMA / RIESGO VITAL',
          subtitulo: 'Nivel 3 · Rojo',
          onTap: _sending ? null : () => _send('3', 'Arma o riesgo vital'),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status, semanticsLabel: 'Estado: $_status'),
          ),
        ),
        const SizedBox(height: 12),
        _RecentIncidents(user: widget.usuario, service: _incidents),
      ],
    ),
  );
}

class _RecentIncidents extends StatelessWidget {
  const _RecentIncidents({required this.user, required this.service});
  final Usuario user;
  final IncidentesServicio service;

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Incidente>>(
    stream: service.emitidosPor(user),
    builder: (context, snapshot) {
      final values = snapshot.data ?? const <Incidente>[];
      if (values.isEmpty) return const Text('Aún no hay incidentes emitidos.');
      final incident = values.first;
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colores.porNivel(incident.nivel),
            child: Text(incident.nivel),
          ),
          title: Text(
            '${incident.simulacro ? 'SIMULACRO · ' : ''}${incident.etiqueta}',
          ),
          subtitle: Text(
            '${incident.salaNombre} · ${incident.estado.etiqueta}${incident.acknowledgedByName == null ? '' : ' por ${incident.acknowledgedByName}'}',
          ),
          trailing:
              [
                EstadoIncidente.created,
                EstadoIncidente.notified,
              ].contains(incident.estado)
              ? IconButton(
                  tooltip: 'Cancelar incidente',
                  icon: const Icon(Icons.cancel_outlined),
                  onPressed: () => service.cancelar(
                    incident.id,
                    'Cancelado por el emisor desde Android',
                  ),
                )
              : null,
        ),
      );
    },
  );
}
