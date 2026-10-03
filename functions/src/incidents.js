"use strict";

const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {
  LEVELS,
  LEVEL_LABELS,
  RECIPIENT_ROLES,
  STATES,
  INCIDENT_TTL_SECONDS,
} = require("./constants");
const {principal, requireSameSite} = require("./authz");
const {
  safeId,
  optionalString,
  requiredString,
  idempotencyKey,
  requestFingerprint,
  sha256,
} = require("./validation");

const RATE_WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 10;
const MIN_INTERVAL_MS = 3_000;

function validateLevel(value) {
  const level = String(value || "");
  if (!LEVELS.includes(level)) {
    throw new HttpsError("invalid-argument", "nivel debe ser 1, 2 o 3.");
  }
  return level;
}

function normalizeIncidentRequest(data) {
  const level = validateLevel(data && data.nivel);
  const roomId = optionalString(data && data.salaId, "salaId", 64);
  if (roomId !== null) safeId(roomId, "salaId");
  return {
    level,
    roomId,
    drill: data && data.simulacro === true,
    idempotencyKey: idempotencyKey(data && data.idempotencyKey),
  };
}

function incidentIdFor(scope, key) {
  return `inc_${sha256(`${scope}:${key}`).slice(0, 40)}`;
}

function rateLimitValue(snapshot, nowMillis) {
  const previous = snapshot.exists && Array.isArray(snapshot.data().timestamps) ?
    snapshot.data().timestamps.filter((item) => Number.isFinite(item) && item > nowMillis - RATE_WINDOW_MS) : [];
  const last = previous.length ? previous[previous.length - 1] : 0;
  if (nowMillis - last < MIN_INTERVAL_MS || previous.length >= MAX_PER_WINDOW) {
    throw new HttpsError("resource-exhausted", "Demasiadas solicitudes; espera unos segundos.");
  }
  previous.push(nowMillis);
  return {timestamps: previous, updatedAt: Timestamp.fromMillis(nowMillis)};
}

async function roomSnapshot(transaction, db, siteId, roomId) {
  if (!roomId) return {id: null, name: "Ubicación no especificada"};
  const roomRef = db.collection("sedes").doc(siteId).collection("salas").doc(roomId);
  const snapshot = await transaction.get(roomRef);
  if (!snapshot.exists || snapshot.data().active === false) {
    throw new HttpsError("failed-precondition", "La sala no existe o está inactiva.");
  }
  return {id: roomId, name: String(snapshot.data().nombre || roomId).slice(0, 120)};
}

async function createIncident(request) {
  const actor = principal(request, ["docente", "inspector", "direccion", "admin"]);
  const input = normalizeIncidentRequest(request.data || {});
  const db = getFirestore();
  const incidentId = incidentIdFor(actor.uid, input.idempotencyKey);
  const incidentRef = db.collection("incidentes").doc(incidentId);
  const rateRef = db.collection("limites").doc(`usuario_${actor.uid}`);
  const nowMillis = Date.now();
  const fingerprint = requestFingerprint({
    nivel: input.level,
    salaId: input.roomId,
    simulacro: input.drill,
  });

  const result = await db.runTransaction(async (transaction) => {
    const existing = await transaction.get(incidentRef);
    if (existing.exists) {
      if (existing.data().requestFingerprint !== fingerprint) {
        throw new HttpsError("already-exists", "La clave de idempotencia ya se usó con otros datos.");
      }
      return {incidentId, duplicate: true, state: existing.data().estado};
    }

    const rateSnapshot = await transaction.get(rateRef);
    const room = await roomSnapshot(transaction, db, actor.siteId, input.roomId);
    const rateValue = rateLimitValue(rateSnapshot, nowMillis);
    const createdAt = Timestamp.fromMillis(nowMillis);
    const expiresAt = Timestamp.fromMillis(nowMillis + INCIDENT_TTL_SECONDS * 1000);
    const incident = {
      schemaVersion: 2,
      nivel: input.level,
      etiqueta: LEVEL_LABELS[input.level],
      sedeId: actor.siteId,
      salaId: room.id,
      salaNombreSnapshot: room.name,
      origen: "app",
      emisorUid: actor.uid,
      nombreEmisorSnapshot: actor.name,
      dispositivoId: null,
      simulacro: input.drill,
      estado: STATES.CREATED,
      createdAt,
      expiresAt,
      retentionDeleteAt: null,
      acknowledgedAt: null,
      acknowledgedBy: null,
      acknowledgedByName: null,
      resolvedAt: null,
      resolvedBy: null,
      cancelledAt: null,
      cancelledBy: null,
      cancellationReason: null,
      fanoutStatus: "PENDING",
      fanoutAttempts: 0,
      deliveredCount: 0,
      failedCount: 0,
      requestFingerprint: fingerprint,
      updatedAt: createdAt,
    };
    transaction.set(rateRef, rateValue);
    transaction.create(incidentRef, incident);
    transaction.create(incidentRef.collection("eventos").doc(), {
      type: "CREATED",
      at: createdAt,
      actorUid: actor.uid,
      actorRole: actor.role,
      source: "app",
    });
    return {incidentId, duplicate: false, state: STATES.CREATED, expiresAt: expiresAt.toMillis()};
  });

  logger.info("incident_created", {
    incidentId,
    siteId: actor.siteId,
    level: input.level,
    drill: input.drill,
    duplicate: result.duplicate,
  });
  return result;
}

function incidentIdFrom(data) {
  return safeId(data && data.incidentId, "incidentId");
}

function isExpired(incident, nowMillis) {
  return incident.expiresAt && typeof incident.expiresAt.toMillis === "function" &&
    incident.expiresAt.toMillis() <= nowMillis;
}

function clientTelemetry(data) {
  const source = data && typeof data.telemetry === "object" && data.telemetry !== null ? data.telemetry : {};
  const result = {};
  const now = Date.now();
  const minimum = now - 24 * 60 * 60 * 1000;
  const maximum = now + 5 * 60 * 1000;
  for (const [inputName, outputName] of [
    ["receivedAtMillis", "clientReceivedAt"],
    ["notificationPresentedAtMillis", "clientNotificationPresentedAt"],
    ["alarmPresentedAtMillis", "clientAlarmPresentedAt"],
  ]) {
    const value = Number(source[inputName]);
    if (Number.isSafeInteger(value) && value >= minimum && value <= maximum) {
      result[outputName] = Timestamp.fromMillis(value);
    }
  }
  if (source.installationId !== undefined && source.installationId !== null && source.installationId !== "") {
    result.installationId = safeId(source.installationId, "telemetry.installationId");
  }
  return result;
}

async function acknowledgeIncident(request) {
  const actor = principal(request, ["inspector", "direccion", "admin"]);
  const incidentId = incidentIdFrom(request.data);
  const telemetry = clientTelemetry(request.data);
  const db = getFirestore();
  const ref = db.collection("incidentes").doc(incidentId);
  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Incidente no encontrado.");
    const incident = snapshot.data();
    requireSameSite(actor, incident);
    if (!RECIPIENT_ROLES[incident.nivel]?.includes(actor.role)) {
      throw new HttpsError("permission-denied", "Tu rol no recibe este nivel.");
    }
    if (incident.estado === STATES.ACKNOWLEDGED) {
      return {
        incidentId,
        duplicate: true,
        acknowledgedBy: incident.acknowledgedBy,
        acknowledgedByName: incident.acknowledgedByName,
      };
    }
    if (![STATES.CREATED, STATES.NOTIFIED].includes(incident.estado)) {
      throw new HttpsError("failed-precondition", `No se puede reconocer desde ${incident.estado}.`);
    }
    const now = Timestamp.now();
    if (isExpired(incident, now.toMillis())) {
      transaction.update(ref, {estado: STATES.EXPIRED, updatedAt: now, retentionDeleteAt: retentionDate(now)});
      transaction.create(ref.collection("eventos").doc(), {type: "EXPIRED", at: now, source: "backend"});
      return {incidentId, expired: true};
    }
    transaction.update(ref, {
      estado: STATES.ACKNOWLEDGED,
      acknowledgedAt: now,
      acknowledgedBy: actor.uid,
      acknowledgedByName: actor.name,
      updatedAt: now,
    });
    transaction.create(ref.collection("eventos").doc(), {
      type: "ACKNOWLEDGED",
      at: now,
      actorUid: actor.uid,
      actorRole: actor.role,
      source: "app",
      telemetryServerReceivedAt: now,
      ...telemetry,
    });
    return {incidentId, duplicate: false, acknowledgedBy: actor.uid, acknowledgedByName: actor.name};
  });
  if (result.expired) throw new HttpsError("deadline-exceeded", "El incidente ya expiró.");
  return result;
}

function retentionDate(fromTimestamp) {
  return Timestamp.fromMillis(fromTimestamp.toMillis() + 90 * 24 * 60 * 60 * 1000);
}

async function resolveIncident(request) {
  const actor = principal(request, ["inspector", "direccion", "admin"]);
  const incidentId = incidentIdFrom(request.data);
  const db = getFirestore();
  const ref = db.collection("incidentes").doc(incidentId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Incidente no encontrado.");
    const incident = snapshot.data();
    requireSameSite(actor, incident);
    if (incident.estado === STATES.RESOLVED) return {incidentId, duplicate: true};
    if (incident.estado !== STATES.ACKNOWLEDGED) {
      throw new HttpsError("failed-precondition", "Solo un incidente reconocido puede resolverse.");
    }
    if (actor.role !== "admin" && incident.acknowledgedBy !== actor.uid) {
      throw new HttpsError("permission-denied", "Solo quien reconoció el incidente o un administrador puede resolverlo.");
    }
    const now = Timestamp.now();
    transaction.update(ref, {
      estado: STATES.RESOLVED,
      resolvedAt: now,
      resolvedBy: actor.uid,
      updatedAt: now,
      retentionDeleteAt: retentionDate(now),
    });
    transaction.create(ref.collection("eventos").doc(), {
      type: "RESOLVED", at: now, actorUid: actor.uid, actorRole: actor.role, source: "app",
    });
    return {incidentId, duplicate: false};
  });
}

async function cancelIncident(request) {
  const actor = principal(request);
  const incidentId = incidentIdFrom(request.data);
  const reason = requiredString(request.data && request.data.reason, "reason", 240);
  const db = getFirestore();
  const ref = db.collection("incidentes").doc(incidentId);
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    if (!snapshot.exists) throw new HttpsError("not-found", "Incidente no encontrado.");
    const incident = snapshot.data();
    requireSameSite(actor, incident);
    if (incident.estado === STATES.CANCELLED) return {incidentId, duplicate: true};
    if (![STATES.CREATED, STATES.NOTIFIED].includes(incident.estado)) {
      throw new HttpsError("failed-precondition", "El incidente ya no puede cancelarse.");
    }
    if (actor.role !== "admin" && incident.emisorUid !== actor.uid) {
      throw new HttpsError("permission-denied", "Solo el emisor o un administrador puede cancelar.");
    }
    const now = Timestamp.now();
    transaction.update(ref, {
      estado: STATES.CANCELLED,
      cancelledAt: now,
      cancelledBy: actor.uid,
      cancellationReason: reason,
      updatedAt: now,
      retentionDeleteAt: retentionDate(now),
    });
    transaction.create(ref.collection("eventos").doc(), {
      type: "CANCELLED", at: now, actorUid: actor.uid, actorRole: actor.role, source: "app", reason,
    });
    return {incidentId, duplicate: false};
  });
}

module.exports = {
  createIncident,
  acknowledgeIncident,
  resolveIncident,
  cancelIncident,
  validateLevel,
  normalizeIncidentRequest,
  incidentIdFor,
  isExpired,
  retentionDate,
  rateLimitValue,
  clientTelemetry,
};
