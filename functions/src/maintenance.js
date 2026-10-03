"use strict";

const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const logger = require("firebase-functions/logger");
const {STATES} = require("./constants");
const {retentionDate} = require("./incidents");

async function expireIncidents() {
  const db = getFirestore();
  const now = Timestamp.now();
  const snapshot = await db.collection("incidentes")
      .where("estado", "in", [STATES.CREATED, STATES.NOTIFIED])
      .where("expiresAt", "<=", now)
      .orderBy("expiresAt")
      .limit(200)
      .get();
  if (snapshot.empty) {
    logger.info("incident_expiration_completed", {expiredCount: 0});
    return;
  }
  const batch = db.batch();
  snapshot.docs.forEach((document) => {
    batch.update(document.ref, {
      estado: STATES.EXPIRED,
      updatedAt: now,
      retentionDeleteAt: retentionDate(now),
    });
    batch.create(document.ref.collection("eventos").doc(), {
      type: "EXPIRED",
      at: now,
      source: "scheduler",
    });
  });
  await batch.commit();
  logger.info("incident_expiration_completed", {expiredCount: snapshot.size});
}

module.exports = {expireIncidents};
