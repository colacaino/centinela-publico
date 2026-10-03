# CENTINELA

Aplicación Android para gestionar alertas e incidentes escolares por rol y sede.
Desarrollada con Flutter/Dart, integración nativa Kotlin y un backend Firebase.

Esta distribución contiene el código de la aplicación, reglas e índices de
Firestore, Functions v2, pruebas locales y un prototipo ESP32. Cada instalación
requiere su propio proyecto Firebase y configuración. Las notificaciones no
constituyen un canal de emergencia con entrega garantizada.

## Funcionalidades

- Autenticación, roles y gestión autorizada de usuarios.
- Alertas por nivel, sede y sala; reconocimiento, resolución y cancelación.
- Primer reconocimiento mediante transacción e idempotencia de solicitudes.
- Registro de instalaciones y envío de notificaciones FCM.
- Expiración programada, auditoría y telemetría.
- Endpoint para ESP32 con TLS y firma HMAC por dispositivo.

Android es la plataforma objetivo. Los directorios iOS, web y escritorio son
plantillas Flutter y no implican soporte validado. `hosting/` contiene páginas
informativas; no es el panel administrativo Next.js propuesto para etapas futuras.
El firmware requiere configurar GPIO, credenciales y circuito y validarlo físicamente.

## Requisitos

- Flutter/Dart compatibles con `pubspec.yaml`.
- Android SDK y herramientas de compilación compatibles con `android/`.
- Node.js 22 para Functions y npm.
- Java compatible con Firebase Emulator Suite para las pruebas de integración.
- Firebase CLI y FlutterFire CLI para configurar un proyecto propio.

## Instalación Android

```powershell
git clone https://github.com/colacaino/centinela-publico.git
Set-Location centinela-publico
flutter pub get
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=TU_PROYECTO_FIREBASE --platforms=android
```

Sustituye `TU_PROYECTO_FIREBASE` por un proyecto de desarrollo que administres.
Verifica que se generen `lib/firebase_options.dart` y
`android/app/google-services.json`. Están excluidos del control de versiones.
Configura Firebase Authentication, Firestore y las funciones necesarias antes
de utilizar el flujo conectado. El repositorio no crea usuarios de prueba ni
incluye cuentas, contraseñas, tokens de dispositivos o exportaciones de usuarios.

Una vez configurado el cliente:

```powershell
flutter analyze
flutter test
flutter run
```

## Backend y pruebas locales

```powershell
Set-Location functions
npm ci
npm run check
npm run test:emulator
npm run audit
```

Las pruebas de integración usan Auth y Firestore emulados con el identificador
ficticio `demo-centinela`. No necesitan acceso a un proyecto productivo. Los datos
y contraseñas que aparecen en pruebas unitarias/emuladas son fixtures sintéticos.
La aceptación de un mensaje por FCM no demuestra recepción o presentación física.

## Configuración y administración

- `.firebaserc.example`: ejemplo para emulación local; copiar como `.firebaserc`
  y configurar explícitamente proyectos propios si se requiere trabajar en nube.
- `functions/.env.example`: variables de configuración sin secretos.
- `android/key.properties.example`: referencia para firma Android.
- `firmware/esp32_button/config.example.h`: plantilla del botón físico.
- `functions/scripts/bootstrap_admin.js`: asigna privilegios a un UID existente,
  con proyecto, sede y confirmación explícitos; no genera usuarios de prueba.
- `functions/scripts/migrate_v2.js`: migración conservadora, dry-run por defecto.

Los scripts administrativos usan Application Default Credentials externas al
repositorio. No incluyen ni reutilizan una sesión Firebase CLI exportada.
Los comandos de despliegue requieren seleccionar explícitamente un proyecto
propio; revisar [despliegue y rollback](docs/DESPLIEGUE_Y_ROLLBACK.md).

## Seguridad y límites

Se excluyen claves de cuentas de servicio, configuración Firebase original,
informes académicos, bases de usuarios, archivos de firma y scripts locales de
provisión de pruebas. Se publica un historial nuevo sin commits del repositorio
privado. La configuración pública del cliente no sustituye las reglas de acceso,
la autorización del backend ni las restricciones de las APIs.

App Check requiere registro y validación antes de activar su exigencia. El uso
de alarmas en pantalla completa depende de permisos y restricciones Android.
Antes de uso institucional se necesitan pruebas físicas, protocolos y un canal
alternativo ante fallos de red o dispositivos.

## Documentación técnica

- [Arquitectura](docs/ARQUITECTURA.md)
- [Modelo de datos](docs/MODELO_DE_DATOS_V2.md)
- [Decisiones arquitectónicas](docs/DECISIONES_ARQUITECTONICAS.md)
- [Despliegue y rollback](docs/DESPLIEGUE_Y_ROLLBACK.md)
- [Pruebas manuales Android](docs/PRUEBAS_MANUALES_ANDROID.md)
- [Prototipo ESP32](firmware/esp32_button/README.md)
