# Protocolo de pruebas manuales Android

Registrar para cada caso fecha, versión/build, modelo, API Android, fabricante,
red, cuenta/rol/sede, resultado, latencia y evidencia. Usar siempre
`simulacro=true` en un proyecto de staging; nunca generar alertas reales.

## Matriz mínima

1. Login válido, inválido, cuenta desactivada, sin claims y otra sede.
2. Cambio obligatorio de contraseña temporal y nuevo login.
3. Registro de dos teléfonos para el mismo usuario; ambos reciben.
4. Logout de uno; ese teléfono deja de recibir y el otro continúa.
5. Niveles: inspector 1/2/3, dirección solo 2/3, admin 1/2/3.
6. Intento cruzado entre sedes: lectura y acción denegadas.
7. App abierta, segundo plano, terminada, pantalla bloqueada y Doze.
8. Notificaciones deshabilitadas y full-screen no autorizado: diagnóstico claro
   y fallback en bandeja, sin prometer apertura automática.
9. Tres incidentes seguidos: cola prioriza nivel 3, no pierde IDs y no repite el
   mismo incidente.
10. Push retrasado más allá de `expiresAt`: no suena ni abre pantalla.
11. Silenciar: detiene solo el equipo y no crea ACK.
12. ACK simultáneo desde dos usuarios: un único responsable first-wins.
13. Resolución por responsable; intento de tercero rechazado; admin permitido.
14. Cancelación por emisor antes de ACK; cancelación después de ACK rechazada.
15. Rotación de token FCM, reinstalación y limpieza de token inválido.
16. Sonido, vibración y restauración de volumen; controles accesibles con
   TalkBack y tamaño de fuente grande.
17. Reboot, actualización de app y cambio de red Wi-Fi/datos móviles.
18. ESP32: firma válida, firma alterada, timestamp vencido, nonce repetido,
   rate limit, dispositivo desactivado y secreto rotado.
19. Corte de Internet/energía del ESP32; documentar degradación y recuperación.
20. Medición extremo a extremo: creación, Function, FCM, visualización, ACK y
   resolución, sin registrar contraseñas, tokens, correos ni secretos en logs.

## Criterios de aceptación iniciales sugeridos

- cero accesos entre sedes en pruebas negativas;
- cero notificaciones de incidentes expirados/cancelados;
- un único ACK autoritativo bajo concurrencia;
- logout invalida la instalación observada;
- 100 % de transiciones quedan en eventos de auditoría;
- latencias reportadas como distribución, no solo promedio;
- fallos FCM y permisos visibles en diagnóstico;
- restauración exacta del volumen previo al cerrar la alerta.

Los umbrales de latencia y disponibilidad deben definirse con la institución y
validarse empíricamente; no se inventan en esta etapa.
