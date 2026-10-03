import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../core/colores.dart';
import '../core/modelos.dart';
import '../servicios/incidentes_servicio.dart';
import '../servicios/volumen_alarma.dart';

class AlertaFullscreen extends StatefulWidget {
  const AlertaFullscreen({super.key, required this.incidente});
  final Incidente incidente;

  @override
  State<AlertaFullscreen> createState() => _AlertaFullscreenState();
}

class _AlertaFullscreenState extends State<AlertaFullscreen> {
  final _player = AudioPlayer();
  final _service = IncidentesServicio();
  StreamSubscription<Incidente?>? _subscription;
  late Incidente _incident;
  int? _originalVolume;
  bool _silenced = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _incident = widget.incidente;
    _startAlarm();
    _subscription = _service.observar(_incident.id).listen((latest) {
      if (latest == null || !mounted) return;
      setState(() => _incident = latest);
      if (latest.estado == EstadoIncidente.acknowledged ||
          latest.estado.terminal) {
        _silence();
      }
    });
  }

  Future<void> _startAlarm() async {
    _originalVolume = await VolumenAlarma.obtenerVolumen();
    final maximum = await VolumenAlarma.obtenerVolumenMaximo();
    if (maximum > 0) await VolumenAlarma.fijarVolumen(maximum);
    try {
      if (await Vibration.hasVibrator()) {
        await Vibration.vibrate(
          pattern: [0, 800, 400, 800, 400],
          intensities: [0, 255, 0, 255, 0],
          repeat: 0,
        );
      }
    } catch (_) {}
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sonidos/alerta.wav'));
    } catch (_) {}
  }

  Future<void> _silence() async {
    if (_silenced) return;
    _silenced = true;
    try {
      await Vibration.cancel();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    if (_originalVolume != null) {
      await VolumenAlarma.fijarVolumen(_originalVolume!);
    }
    if (mounted) setState(() {});
  }

  Future<void> _acknowledge() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _service.reconocer(_incident.id);
      await _silence();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'No fue posible reconocer; otro usuario pudo cambiar el estado.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _silence();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Colores.porNivel(_incident.nivel);
    final alreadyHandled =
        _incident.estado == EstadoIncidente.acknowledged ||
        _incident.estado.terminal;
    return PopScope(
      canPop: _silenced || alreadyHandled,
      child: Scaffold(
        backgroundColor: color,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Icon(
                  _incident.simulacro
                      ? Icons.science_outlined
                      : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 86,
                ),
                Text(
                  _incident.simulacro
                      ? 'SIMULACRO · NIVEL ${_incident.nivel}'
                      : '¡ALERTA NIVEL ${_incident.nivel}!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _incident.etiqueta.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  color: Colors.white.withValues(alpha: 0.18),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _row(
                          Icons.location_on,
                          'Ubicación',
                          _incident.salaNombre,
                        ),
                        _row(
                          Icons.person,
                          'Emitido por',
                          _incident.nombreEmisor,
                        ),
                        _row(Icons.access_time, 'Hora', _incident.horaTexto),
                        _row(Icons.sync, 'Estado', _incident.estado.etiqueta),
                        if (_incident.acknowledgedByName != null)
                          _row(
                            Icons.verified_user,
                            'Reconocido por',
                            _incident.acknowledgedByName!,
                          ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!alreadyHandled) ...[
                  OutlinedButton.icon(
                    onPressed: _silenced ? null : _silence,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: const Icon(Icons.volume_off),
                    label: const Text('SILENCIAR ESTE DISPOSITIVO'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _acknowledge,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: color,
                      minimumSize: const Size.fromHeight(72),
                    ),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.pan_tool_alt),
                    label: const Text(
                      'RECONOCER Y ASUMIR',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: color,
                      minimumSize: const Size.fromHeight(60),
                    ),
                    child: const Text('CERRAR'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$label\n$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
