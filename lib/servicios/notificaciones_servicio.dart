import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/modelos.dart';
import '../core/notificacion_utils.dart';
import '../pantallas/alerta_fullscreen.dart';
import 'incidentes_servicio.dart';
import 'telemetria_servicio.dart';

const _channelId = 'alertas_centinela_v3';

const AndroidNotificationChannel canalAlertas = AndroidNotificationChannel(
  _channelId,
  'Alertas CENTINELA',
  description: 'Incidentes escolares vigentes que requieren atención',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('alerta'),
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

AndroidNotificationDetails _androidDetails() => AndroidNotificationDetails(
  canalAlertas.id,
  canalAlertas.name,
  channelDescription: canalAlertas.description,
  importance: Importance.max,
  priority: Priority.max,
  category: AndroidNotificationCategory.alarm,
  fullScreenIntent: true,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('alerta'),
  audioAttributesUsage: AudioAttributesUsage.alarm,
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 800, 400, 800, 400]),
  visibility: NotificationVisibility.public,
  autoCancel: true,
);

Future<Incidente?> _fetchAuthorizedIncident(String incidentId) async {
  if (FirebaseAuth.instance.currentUser == null) return null;
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('incidentes')
        .doc(incidentId)
        .get();
    if (!snapshot.exists || snapshot.data() == null) return null;
    final incident = Incidente.desdeDoc(snapshot.id, snapshot.data()!);
    return incident.vigente ? incident : null;
  } catch (_) {
    return null;
  }
}

@pragma('vm:entry-point')
Future<void> mostrarNotificacionDesdePush(Map<String, dynamic> data) async {
  if (!pushVigente(data)) return;
  final incidentId = data['incidentId'].toString();
  await TelemetriaServicio.instancia.registrarRecepcion(incidentId);
  if (await _fetchAuthorizedIncident(incidentId) == null) return;
  final plugin = FlutterLocalNotificationsPlugin();
  const initialization = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(
    settings: const InitializationSettings(android: initialization),
  );
  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(canalAlertas);
  await plugin.show(
    id: notificationId(incidentId),
    title: data['titulo']?.toString() ?? 'Alerta CENTINELA',
    body: data['cuerpo']?.toString() ?? '',
    notificationDetails: NotificationDetails(android: _androidDetails()),
    payload: jsonEncode({'incidentId': incidentId}),
  );
  await TelemetriaServicio.instancia.registrarNotificacionPresentada(
    incidentId,
  );
}

class NotificacionesServicio {
  NotificacionesServicio._();
  static final instancia = NotificacionesServicio._();

  final navigatorKey = GlobalKey<NavigatorState>();
  final _local = FlutterLocalNotificationsPlugin();
  final _incidents = IncidentesServicio();
  final List<Incidente> _queue = [];
  final Set<String> _queued = {};
  Set<String> _processed = {};
  bool _presenting = false;
  bool _initialized = false;

  Future<void> inicializar() async {
    if (_initialized) return;
    _initialized = true;
    final preferences = await SharedPreferences.getInstance();
    _processed =
        preferences.getStringList('centinela_processed_incidents')?.toSet() ??
        <String>{};

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    const initialization = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      settings: const InitializationSettings(android: initialization),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final value = jsonDecode(payload);
        if (value is Map && value['incidentId'] != null) {
          procesarId(value['incidentId'].toString());
        }
      },
    );
    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(canalAlertas);
    await android?.requestNotificationsPermission();

    FirebaseMessaging.onMessage.listen((message) async {
      if (!pushVigente(message.data)) return;
      await mostrarNotificacionDesdePush(message.data);
      await procesarId(message.data['incidentId'].toString());
    });
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final id = message.data['incidentId']?.toString();
      if (id != null) procesarId(id);
    });

    final launch = await _local.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) && payload != null) {
      final value = jsonDecode(payload);
      if (value is Map && value['incidentId'] != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => procesarId(value['incidentId'].toString()),
        );
      }
    }
  }

  Future<void> procesarId(String incidentId) async {
    final incident = await _incidents.obtenerVigente(incidentId);
    if (incident != null) await procesarIncidente(incident);
  }

  Future<void> procesarIncidente(Incidente incident) async {
    if (!incident.vigente ||
        _processed.contains(incident.id) ||
        _queued.contains(incident.id)) {
      return;
    }
    _queue.add(incident);
    _queued.add(incident.id);
    _queue.sort((a, b) {
      final byLevel = int.parse(b.nivel).compareTo(int.parse(a.nivel));
      return byLevel != 0 ? byLevel : a.createdAt.compareTo(b.createdAt);
    });
    await _drain();
  }

  Future<void> _drain() async {
    if (_presenting || _queue.isEmpty) return;
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
      return;
    }
    _presenting = true;
    while (_queue.isNotEmpty) {
      final incident = _queue.removeAt(0);
      _queued.remove(incident.id);
      final latest = await _incidents.obtenerVigente(incident.id);
      if (latest != null) {
        await TelemetriaServicio.instancia.registrarAlarmaPresentada(
          incident.id,
        );
        await navigator.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => AlertaFullscreen(incidente: latest),
          ),
        );
      }
      await _markProcessed(incident.id);
      await _local.cancel(id: notificationId(incident.id));
    }
    _presenting = false;
  }

  Future<void> _markProcessed(String id) async {
    _processed.add(id);
    if (_processed.length > 200) {
      _processed = _processed.skip(_processed.length - 200).toSet();
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      'centinela_processed_incidents',
      _processed.toList(),
    );
  }

  Future<bool> notificacionesHabilitadas() async =>
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.areNotificationsEnabled() ??
      false;
}
