# Despliegue seguro y rollback de CENTINELA v2

## Regla principal

Esta distribución no está vinculada a un proyecto Firebase real. Crear y
configurar un entorno propio. Las Rules estrictas rompen deliberadamente el cliente legado;
por ello no deben publicarse antes de migrar cuentas y distribuir Android v2.

## Requisitos previos

1. Designar responsable institucional, política de retención y contacto de
   privacidad.
2. Crear un proyecto Firebase de staging separado y repetir allí todo el flujo.
3. Elegir `applicationId` institucional. Registrar la nueva app Android en
   Firebase, descargar su `google-services.json` y actualizar namespace/Kotlin.
4. Generar un keystore release fuera del repositorio y completar
   `android/key.properties` desde el ejemplo.
5. Configurar presupuestos, alertas de cuota, propietarios y mínimo privilegio
   en Google Cloud.
6. Obtener aprobación para el uso de notificación full-screen y validar las
   políticas vigentes de Google Play.

## Respaldo antes de cualquier escritura

Realizar un export administrado de Firestore a un bucket con retención y acceso
restringido. Registrar proyecto, base, bucket, fecha, responsable y verificación
del export. Exportar además la lista de usuarios Auth por un canal seguro. El
repositorio no automatiza ni ejecuta este paso porque afecta datos productivos.

Registrar y verificar la versión de recuperación antes de modificar un entorno.
Esta distribución pública comienza con un historial independiente y no contiene
tags ni commits del repositorio privado.

## Secuencia recomendada

1. Ejecutar localmente:

   ```powershell
   flutter analyze
   flutter test
   cd functions
   npm ci
   npm run check
   npm run test:emulator
   ```

2. Desplegar **solo índices** y esperar a que todos queden `READY`.
3. Crear sede y salas normalizadas en staging.
4. Preparar el primer administrador con credenciales ADC externas:

   ```powershell
   node functions/scripts/bootstrap_admin.js --project=PROYECTO --uid=UID --site-id=SEDE --confirm=PROYECTO:UID
   ```

5. Ejecutar la migración en dry-run y revisar cada `SKIP_*`:

   ```powershell
   node functions/scripts/migrate_v2.js --project=PROYECTO --default-site-id=SEDE --migrate-alerts
   ```

6. Tras el respaldo y aprobación, aplicar agregando
   `--apply --confirm=PROYECTO`. Los alertas históricos se archivan como
   `EXPIRED` para que jamás disparen notificaciones.
7. Desplegar las Functions v2 por nombre con `npm run deploy:v2`. Esta orden no
   incluye los nombres legados y evita aceptar su eliminación accidental.
8. Registrar App Check con Play Integrity y tokens debug autorizados. Mantener
   `ENFORCE_APP_CHECK=false` durante la observación inicial.
9. Distribuir APK/AAB v2 firmado a un grupo piloto. Validar cambio de contraseña,
   instalación FCM, sede, niveles, ACK y resolución.
10. Desplegar `firestore.rules` cuando ya no existan clientes legados activos.
11. Habilitar TTL para `retentionDeleteAt` en los collection groups `incidentes`
    y `nonces`, después de aprobar 90 días u otro plazo institucional.
12. Migrar cada ESP32: secreto aleatorio individual en Secret Manager,
    asociación Firestore, TLS, HMAC y prueba física. Recién entonces retirar
    `alertaDesdeBoton`/`notificarAlerta` legadas.
13. Desplegar Hosting para publicar información y privacidad; antes del
    despliegue remoto el sitio continúa mostrando su estado anterior.
14. Observar al menos un ciclo piloto y recién después habilitar enforcement de
    App Check en Functions/Firestore según la consola.

## Rollback por etapa

| Falla | Respuesta segura |
|---|---|
| Índice no listo | detener rollout; no cambiar Rules |
| Claims incorrectos | corregir dry-run/mapeo y revocar tokens; no abrir Rules |
| Function v2 defectuosa | mantener nombre legado mientras el dispositivo no haya migrado; corregir/republicar solo la Function v2 |
| Android v2 defectuoso | detener distribución y volver a la última versión v2 firmada; mantener backend/Rules seguros |
| Rules bloquean usuarios válidos | corregir claims o desplegar una revisión segura de Rules; **no restaurar** `allow read, write: if auth != null` |
| Fan-out FCM falla | conservar incidentes y auditoría, corregir índice/IAM/FCM y reintentar en staging; no falsificar `deliveredCount` |
| ESP32 falla | desactivar ese documento de dispositivo y conservar el endpoint legado solo durante la ventana aprobada |
| App Check rechaza clientes | volver enforcement a modo monitor mientras se corrigen registros; no desactivar Auth/Rules |

No se proporciona un script de borrado masivo como “rollback”. La migración
agrega campos y crea archivos históricos sin borrar `alertas`; el respaldo
administrado es la recuperación de datos autorizada. Un rollback nunca debe
reintroducir las Rules permisivas detectadas en el prototipo.

## Secret Manager e IAM para ESP32

Por dispositivo:

1. generar al menos 32 bytes aleatorios;
2. crear `secretId` sin incluir el valor en Firestore/Git;
3. otorgar a la identidad de ejecución de la Function solo acceso de lectura a
   las versiones necesarias;
4. registrar `dispositivos/{deviceId}` con sede/sala del servidor;
5. provisionar el mismo secreto en el hardware por un canal seguro;
6. rotar creando una versión nueva, actualizando el dispositivo y retirando la
   anterior tras la prueba.

## Criterio de go/no-go

No pasar a producción si falta cualquiera de estos puntos: backup verificado,
keystore institucional, app ID definitivo, reglas probadas, cuentas con claims,
salas configuradas, App Check observado, hardware físico validado, prueba en
pantalla bloqueada y política de respuesta humana. FCM no debe considerarse un
canal de entrega garantizada.
