"use strict";

const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const logger = require("firebase-functions/logger");
const {
  INCIDENT_TTL_SECONDS,
  LEVEL_LABELS,
  RECIPIENT_ROLES,
  STATES,
  TERMINAL_STATES,
} = require("./constants");

const MAX_MULTICAST = 500;

async function claimDispatch(db, incidentRef, dispatchRef) {
  return db.runTransaction(async (transaction) => {
    const [incidentSnapshot, dispatchSnapshot] = await Promise.all([
      transaction.get(incidentRef),
      transaction.get(dispatchRef),
    ]);
    if (!incidentSnapshot.exists) return {claimed: false, reason: "missing"};
    const incident = incidentSnapshot.data();
    if (TERMINAL_STATES.includes(incident.estado)) return {claimed: false, reason: "terminal"};
    if (dispatchSnapshot.exists && dispatchSnapshot.data().status === "COMPLETED") {
      return {claimed: false, reason: "completed"};
    }
    if (dispatchSnapshot.exists && dispatchSnapshot.data().status === "IN_PROGRESS") {
      const updatedAt = dispatchSnapshot.data().updatedAt;
      if (updatedAt && Date.now() - updatedAt.toMillis() < 45_000) {
        throw new Error("dispatch_already_in_progress");
      }
    }
    const attempts = (dispatchSnapshot.exists ? Number(dispatchSnapshot.data().attempts || 0) : 0) + 1;
    const startedAt = Timestamp.now();
    transaction.set(dispatchRef, {
      incidentId: incidentRef.id,
      status: "IN_PROGRESS",
      attempts,
      startedAt,
      updatedAt: startedAt,
    }, {merge: true});
    transaction.update(incidentRef, {
      fanoutStatus: "IN_PROGRESS",
      fanoutAttempts: attempts,
      fanoutStartedAt: startedAt,
      updatedAt: startedAt,
    });
    return {claimed: true, incident, attempts};
  });
}

async function recipientInstallations(db, incident) {
  const roles = RECIPIENT_ROLES[String(incident.nivel)] || [];
  if (!roles.length) return new Map();
  const snapshot = await db.collectionGroup("instalaciones")
      .where("sedeId", "==", incident.sedeId)
      .where("role", "in", roles)
      .where("active", "==", true)
      .get();
  const byToken = new Map();
  snapshot.forEach((document) => {
    const installation = document.data();
    const token = typeof installation.fcmToken === "string" ? installation.fcmToken.trim() : "";
    if (!token || installation.uid === incident.emisorUid) return;
    if (!byToken.has(token)) byToken.set(token, []);
    byToken.get(token).push(document.ref);
  });
  return byToken;
}

function notificationData(incidentId, incident) {
  return {
    schemaVersion: "2",
    type: "INCIDENT_CREATED",
    incidentId,
    nivel: String(incident.nivel),
    sedeId: String(incident.sedeId),
    salaId: String(incident.salaId || ""),
    salaNombre: String(incident.salaNombreSnapshot || "Ubicación no especificada"),
    nombreEmisor: String(incident.nombreEmisorSnapshot || "CENTINELA"),
    estado: String(incident.estado),
    createdAtMillis: String(incident.createdAt.toMillis()),
    expiresAtMillis: String(incident.expiresAt.toMillis()),
    simulacro: String(incident.simulacro === true),
    titulo: `${incident.simulacro === true ? "SIMULACRO · " : ""}${LEVEL_LABELS[incident.nivel] || "Alerta CENTINELA"}`,
    cuerpo: `${incident.salaNombreSnapshot || "Ubicación no especificada"} · ${incident.nombreEmisorSnapshot || "CENTINELA"}`,
    click_action: "FLUTTER_NOTIFICATION_CLICK",
  };
}

async function deactivateInvalidTokens(db, invalidEntries) {
  for (let offset = 0; offset < invalidEntries.length; offset += 450) {
    const batch = db.batch();
    invalidEntries.slice(offset, offset + 450).forEach(({ref}) => {
      batch.set(ref, {active: false, fcmToken: null, invalidatedAt: Timestamp.now(), updatedAt: Timestamp.now()}, {merge: true});
    });
    await batch.commit();
  }
}

async function executeNotificationDispatch(event) {
  const snapshot = event.data;
  if (!snapshot) return;
  const db = getFirestore();
  const incidentRef = snapshot.ref;
  const dispatchRef = db.collection("despachosNotificacion").doc(incidentRef.id);
  const claim = await claimDispatch(db, incidentRef, dispatchRef);
  if (!claim.claimed) {
    logger.info("incident_dispatch_skipped", {incidentId: incidentRef.id, reason: claim.reason});
    return;
  }

  const incident = claim.incident;
  if (!incident.expiresAt || incident.expiresAt.toMillis() <= Date.now()) {
    const now = Timestamp.now();
    await incidentRef.update({
      estado: STATES.EXPIRED,
      fanoutStatus: "SKIPPED_EXPIRED",
      fanoutCompletedAt: now,
      updatedAt: now,
    });
    await dispatchRef.set({status: "COMPLETED", reason: "expired", completedAt: now, updatedAt: now}, {merge: true});
    return;
  }

  const recipients = await recipientInstallations(db, incident);
  const tokens = [...recipients.keys()];
  let successCount = 0;
  let failureCount = 0;
  const invalidEntries = [];
  for (let offset = 0; offset < tokens.length; offset += MAX_MULTICAST) {
    const chunk = tokens.slice(offset, offset + MAX_MULTICAST);
    const response = await getMessaging().sendEachForMulticast({
      tokens: chunk,
      data: notificationData(incidentRef.id, incident),
      android: {
        priority: "high",
        ttl: INCIDENT_TTL_SECONDS * 1000,
        restrictedPackageName: "com.example.centinela",
      },
    });
    successCount += response.successCount;
    failureCount += response.failureCount;
    response.responses.forEach((result, index) => {
      const code = result.error && result.error.code;
      if (!result.success && [
        "messaging/invalid-registration-token",
        "messaging/registration-token-not-registered",
      ].includes(code)) {
        (recipients.get(chunk[index]) || []).forEach((ref) => invalidEntries.push({ref}));
      }
    });
  }
  if (invalidEntries.length) await deactivateInvalidTokens(db, invalidEntries);

  const completedAt = Timestamp.now();
  await db.runTransaction(async (transaction) => {
    const current = await transaction.get(incidentRef);
    if (current.exists) {
      const update = {
        fanoutStatus: "COMPLETED",
        deliveredCount: successCount,
        failedCount: failureCount,
        notifiedAt: completedAt,
        fanoutCompletedAt: completedAt,
        updatedAt: completedAt,
      };
      if (current.data().estado === STATES.CREATED) update.estado = STATES.NOTIFIED;
      transaction.update(incidentRef, update);
      transaction.create(incidentRef.collection("eventos").doc(), {
        type: "NOTIFIED",
        at: completedAt,
        source: "backend",
        deliveredCount: successCount,
        failedCount: failureCount,
        recipientInstallations: tokens.length,
      });
    }
    transaction.set(dispatchRef, {
      status: "COMPLETED",
      successCount,
      failureCount,
      recipientInstallations: tokens.length,
      completedAt,
      updatedAt: completedAt,
    }, {merge: true});
  });
  logger.info("incident_dispatched", {
    incidentId: incidentRef.id,
    siteId: incident.sedeId,
    level: incident.nivel,
    recipients: tokens.length,
    successCount,
    failureCount,
    invalidTokens: invalidEntries.length,
    attempt: claim.attempts,
  });
}

async function notifyCreatedIncident(event) {
  try {
    return await executeNotificationDispatch(event);
  } catch (error) {
    if (String(error.message) === "dispatch_already_in_progress") throw error;
    const snapshot = event.data;
    if (snapshot) {
      const now = Timestamp.now();
      await Promise.allSettled([
        snapshot.ref.set({fanoutStatus: "FAILED_RETRYABLE", updatedAt: now}, {merge: true}),
        getFirestore().collection("despachosNotificacion").doc(snapshot.id).set({
          status: "FAILED",
          errorCode: String(error.code || "unknown").slice(0, 120),
          updatedAt: now,
        }, {merge: true}),
      ]);
      logger.error("incident_dispatch_failed", {
        incidentId: snapshot.id,
        errorCode: error.code || "unknown",
      });
    }
    throw error;
  }
}

module.exports = {
  notifyCreatedIncident,
  notificationData,
  recipientInstallations,
  claimDispatch,
};
