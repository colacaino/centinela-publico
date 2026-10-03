import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/colores.dart';
import 'firebase_options.dart';
import 'pantallas/auth_gate.dart';
import 'servicios/instalaciones_servicio.dart';
import 'servicios/notificaciones_servicio.dart';

@pragma('vm:entry-point')
Future<void> manejadorMensajeSegundoPlano(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await mostrarNotificacionDesdePush(message.data);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (error) {
    debugPrint('App Check no pudo activarse: $error');
  }
  FirebaseMessaging.onBackgroundMessage(manejadorMensajeSegundoPlano);
  await NotificacionesServicio.instancia.inicializar();
  await InstalacionesServicio.instancia.inicializar();
  runApp(const CentinelaApp());
}

class CentinelaApp extends StatelessWidget {
  const CentinelaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CENTINELA',
    debugShowCheckedModeBanner: false,
    navigatorKey: NotificacionesServicio.instancia.navigatorKey,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colores.rojo),
      scaffoldBackgroundColor: Colores.fondo,
      visualDensity: VisualDensity.standard,
    ),
    home: const AuthGate(),
  );
}
