import 'dart:async';
import 'package:flutter/material.dart';
import '../core/modelos.dart';
import '../servicios/incidentes_servicio.dart';
import '../servicios/notificaciones_servicio.dart';

class ReceptorListener extends StatefulWidget {
  const ReceptorListener({
    super.key,
    required this.usuario,
    required this.child,
  });
  final Usuario usuario;
  final Widget child;

  @override
  State<ReceptorListener> createState() => _ReceptorListenerState();
}

class _ReceptorListenerState extends State<ReceptorListener> {
  StreamSubscription<List<Incidente>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant ReceptorListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.usuario.uid != widget.usuario.uid) _subscribe();
  }

  void _subscribe() {
    _subscription?.cancel();
    _subscription = IncidentesServicio().paraReceptor(widget.usuario).listen(
      (incidents) {
        for (final incident in incidents.where((value) => value.vigente)) {
          NotificacionesServicio.instancia.procesarIncidente(incident);
        }
      },
      onError: (Object error, StackTrace stack) =>
          debugPrint('Listener de incidentes: $error'),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
