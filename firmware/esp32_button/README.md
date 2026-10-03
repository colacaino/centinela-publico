# Plantilla segura para botón ESP32

Esta plantilla implementa HTTPS con validación de CA, HMAC-SHA256 por dispositivo,
timestamp NTP, nonce e idempotencia. No contiene credenciales ni presupone el GPIO.

1. Copia `config.example.h` a `config.h`.
2. Registra `dispositivos/{deviceId}` con `active`, `sedeId`, `salaId`, `nombre` y
   `secretId`; nunca guardes el secreto en Firestore.
3. Crea una versión del secreto de al menos 32 bytes en Secret Manager y entrega
   el mismo valor al dispositivo por un canal seguro.
4. Verifica el esquema eléctrico y recién entonces define los GPIO.
5. Pega la CA raíz vigente del endpoint y prueba primero contra un proyecto de
   ensayo. El firmware se niega a compilar con GPIO sin configurar.

La validación física, autonomía eléctrica, protección de la caja, rebote real y
comportamiento sin Wi-Fi siguen siendo pruebas obligatorias en hardware.
