# Decisiones arquitectónicas

## ADR-001 — Android como plataforma objetivo

**Estado:** aceptada.  
**Decisión:** mantener Flutter, pero declarar funcionalmente solo Android durante esta etapa.  
**Motivo:** Firebase y la integración de alarma nativa solo existen para Android; extender plataformas distraería de seguridad y confiabilidad.

## ADR-002 — Autorización con Custom Claims y perfil visible

**Estado:** aceptada para v2.  
**Decisión:** `role`, `sedeId` y `active` se asignan exclusivamente con Admin SDK como Custom Claims. Firestore mantiene un perfil visible sincronizado.  
**Motivo:** el cliente no puede modificar claims; Rules y Functions comparten una fuente confiable de autorización. El perfil permite UI/consultas, pero no otorga privilegios por sí solo.

## ADR-003 — Administración mediante callable Functions

**Estado:** aceptada para v2.  
**Decisión:** retirar `createUserWithEmailAndPassword` del cliente administrador y usar operaciones Admin SDK autorizadas.  
**Motivo:** permite validar rol/sede, sincronizar claims, deshabilitar cuentas y compensar fallos que generarían huérfanos.

## ADR-004 — Nueva colección `incidentes`

**Estado:** aceptada para v2.  
**Decisión:** conservar `alertas` como legado y crear incidentes versionados con estados, expiración y trazabilidad.  
**Motivo:** evita reinterpretar destructivamente documentos existentes y permite una migración controlada.

## ADR-005 — Ubicación por identificadores normalizados

**Estado:** aceptada.  
**Decisión:** usar `sedeId` y `salaId`; `salaId` puede ser nulo mientras se configura el catálogo.  
**Motivo:** los nombres no son estables ni apropiados para autorización. BLE queda detrás de una futura implementación de `LocationProvider` y no se declara completado.

## ADR-006 — Functions v2 nuevas en `southamerica-east1`

**Estado:** preparada, despliegue pendiente.  
**Decisión:** crear endpoints/trigger con nombres v2 en la región de Firestore. No mover ni borrar ciegamente las Functions legadas.  
**Motivo:** reducir latencia y permitir despliegue paralelo/rollback. La migración se realiza después de idempotencia y pruebas.

## ADR-007 — FCM no es garantía de entrega

**Estado:** aceptada.  
**Decisión:** usar prioridad alta, TTL explícito de desarrollo de 120 segundos, validación local de vigencia, ACK y observabilidad.  
**Motivo:** Android, red y FCM pueden retrasar o impedir mensajes; el producto debe medir y degradar con honestidad.

## ADR-008 — Instalaciones multidispositivo

**Estado:** aceptada para v2.  
**Decisión:** `usuarios/{uid}/instalaciones/{installationId}` con token y metadatos operacionales mínimos.  
**Motivo:** evita “último dispositivo gana” y permite desactivar una sesión concreta al logout.

## ADR-009 — ESP32 con HMAC por dispositivo

**Estado:** aceptada para backend/plantilla; validación física pendiente.  
**Decisión:** HMAC-SHA256 sobre contenido canónico con timestamp, nonce e idempotency key. El secreto individual se resuelve desde Secret Manager.  
**Motivo:** elimina la clave global y permite revocación/anti-replay. No se fija GPIO porque no se encontró firmware verificable.

## ADR-010 — Minimizar permisos Android

**Estado:** aceptada para v2.  
**Decisión:** usar notificación full-screen oficial como ruta principal, eliminar overlay/inicio directo desde background y no solicitar ajustes especiales automáticamente.  
**Motivo:** reducir privilegios y cumplir restricciones modernas; el diagnóstico explica estado y fallback.

