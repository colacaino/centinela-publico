"use strict";

const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {principal} = require("./authz");
const {safeId, requiredString} = require("./validation");

async function registerInstallation(request) {
  const actor = principal(request);
  const data = request.data || {};
  const installationId = safeId(data.installationId, "installationId");
  const token = requiredString(data.fcmToken, "fcmToken", 4096);
  const appVersion = String(data.appVersion || "unknown").slice(0, 64);
  const deviceModel = String(data.deviceModel || "Android").slice(0, 120);
  const db = getFirestore();
  const ref = db.collection("usuarios").doc(actor.uid).collection("instalaciones").doc(installationId);
  const now = Timestamp.now();
  const existing = await ref.get();
  await ref.set({
    schemaVersion: 2,
    installationId,
    uid: actor.uid,
    sedeId: actor.siteId,
    role: actor.role,
    platform: "android",
    fcmToken: token,
    appVersion,
    deviceModel,
    active: true,
    appCheckPresent: Boolean(request.app),
    createdAt: existing.exists ? existing.data().createdAt || now : now,
    updatedAt: now,
    lastSeenAt: now,
  }, {merge: true});
  const duplicates = await db.collectionGroup("instalaciones").where("fcmToken", "==", token).get();
  const stale = duplicates.docs.filter((document) => document.ref.path !== ref.path);
  for (let offset = 0; offset < stale.length; offset += 450) {
    const batch = db.batch();
    stale.slice(offset, offset + 450).forEach((document) => {
      batch.set(document.ref, {active: false, fcmToken: null, updatedAt: now}, {merge: true});
    });
    await batch.commit();
  }
  return {installationId, active: true};
}

async function deactivateInstallation(request) {
  const actor = principal(request);
  const installationId = safeId(request.data && request.data.installationId, "installationId");
  const ref = getFirestore()
      .collection("usuarios").doc(actor.uid)
      .collection("instalaciones").doc(installationId);
  await ref.set({active: false, fcmToken: null, updatedAt: Timestamp.now(), lastSeenAt: Timestamp.now()}, {merge: true});
  return {installationId, active: false};
}

module.exports = {registerInstallation, deactivateInstallation};
