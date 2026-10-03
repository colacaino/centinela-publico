import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstalacionesServicio {
  InstalacionesServicio._();
  static final instancia = InstalacionesServicio._();

  final _functions = FirebaseFunctions.instanceFor(
    region: 'southamerica-east1',
  );
  final _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _refreshSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _registeredUid;

  Future<String> get installationId async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString('centinela_installation_id');
    if (current != null && current.isNotEmpty) return current;
    final random = Random.secure();
    final generated = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await preferences.setString('centinela_installation_id', generated);
    return generated;
  }

  Future<void> inicializar() async {
    _authSubscription ??= FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user == null) {
        _registeredUid = null;
        await _refreshSubscription?.cancel();
        _refreshSubscription = null;
        return;
      }
      await registrarActual();
    });
    if (FirebaseAuth.instance.currentUser != null) await registrarActual();
  }

  Future<void> registrarActual() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final claims =
        (await user.getIdTokenResult()).claims ?? const <String, dynamic>{};
    if (claims['mustChangePassword'] == true) return;
    final token = await _messaging.getToken();
    if (token == null) return;
    await _registrar(token);
    if (_registeredUid != user.uid || _refreshSubscription == null) {
      await _refreshSubscription?.cancel();
      _registeredUid = user.uid;
      _refreshSubscription = _messaging.onTokenRefresh.listen((newToken) async {
        if (FirebaseAuth.instance.currentUser?.uid == user.uid) {
          await _registrar(newToken);
        }
      });
    }
  }

  Future<void> _registrar(String token) async {
    final package = await PackageInfo.fromPlatform();
    await _functions.httpsCallable('registrarInstalacionV2').call({
      'installationId': await installationId,
      'fcmToken': token,
      'appVersion': '${package.version}+${package.buildNumber}',
      'deviceModel': Platform.operatingSystemVersion,
    });
  }

  Future<void> desactivarActual() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      await _functions.httpsCallable('desactivarInstalacionV2').call({
        'installationId': await installationId,
      });
    } finally {
      await _refreshSubscription?.cancel();
      _refreshSubscription = null;
      _registeredUid = null;
      await _messaging.deleteToken();
    }
  }
}
