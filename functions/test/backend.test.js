"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {initializeApp, deleteApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const incidents = require("../src/incidents");
const users = require("../src/users");
const maintenance = require("../src/maintenance");

let app;

test.before(() => {
  if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
    throw new Error("Estas pruebas requieren emuladores de Auth y Firestore.");
  }
  app = initializeApp({projectId: "demo-centinela"});
});

test.after(async () => {
  await deleteApp(app);
});

function request(uid, role, siteId, data, extraClaims = {}) {
  return {
    auth: {uid, token: {role, sedeId: siteId, active: true, name: uid, ...extraClaims}},
    app: {appId: "emulator-test"},
    data,
  };
}

test("crear incidente es idempotente y el servidor protege sus campos", async () => {
  const input = request("teacher-idempotent", "docente", "site-a", {
    nivel: "2",
    salaId: null,
    simulacro: true,
    idempotencyKey: "request-idempotent-0001",
  });
  const first = await incidents.createIncident(input);
  const duplicate = await incidents.createIncident(input);
  assert.equal(first.duplicate, false);
  assert.equal(duplicate.duplicate, true);
  assert.equal(first.incidentId, duplicate.incidentId);
  const stored = (await getFirestore().collection("incidentes").doc(first.incidentId).get()).data();
  assert.equal(stored.sedeId, "site-a");
  assert.equal(stored.emisorUid, "teacher-idempotent");
  assert.equal(stored.estado, "CREATED");
  assert.equal(stored.simulacro, true);
  assert.equal(stored.schemaVersion, 2);
});

test("ACK es first-wins, respeta sede y permite resolver al responsable", async () => {
  const created = await incidents.createIncident(request("teacher-state", "docente", "site-a", {
    nivel: "3",
    salaId: null,
    simulacro: false,
    idempotencyKey: "request-state-00000001",
  }));
  await assert.rejects(
      incidents.acknowledgeIncident(request("inspector-other-site", "inspector", "site-b", {incidentId: created.incidentId})),
      (error) => error.code === "permission-denied",
  );
  const acknowledged = await incidents.acknowledgeIncident(
      request("inspector-state", "inspector", "site-a", {incidentId: created.incidentId}),
  );
  assert.equal(acknowledged.duplicate, false);
  const duplicate = await incidents.acknowledgeIncident(
      request("direction-state", "direccion", "site-a", {incidentId: created.incidentId}),
  );
  assert.equal(duplicate.duplicate, true);
  assert.equal(duplicate.acknowledgedBy, "inspector-state");
  await incidents.resolveIncident(
      request("inspector-state", "inspector", "site-a", {incidentId: created.incidentId}),
  );
  const stored = (await getFirestore().collection("incidentes").doc(created.incidentId).get()).data();
  assert.equal(stored.estado, "RESOLVED");
  assert.equal(stored.resolvedBy, "inspector-state");
  assert.ok(stored.retentionDeleteAt);
});

test("administración crea claims y elimina Auth junto con el perfil", async () => {
  const suffix = Date.now();
  const created = await users.createUser(request("admin-backend", "admin", "site-a", {
    nombre: "Usuario Prueba",
    email: `thesis-test-${suffix}@example.com`,
    temporaryPassword: "Temporary123!",
    role: "inspector",
  }));
  const authUser = await getAuth().getUser(created.uid);
  assert.equal(authUser.customClaims.role, "inspector");
  assert.equal(authUser.customClaims.sedeId, "site-a");
  assert.equal(authUser.customClaims.mustChangePassword, true);
  const profile = await getFirestore().collection("usuarios").doc(created.uid).get();
  assert.equal(profile.data().active, true);
  await users.changeInitialPassword(request(created.uid, "inspector", "site-a", {
    newPassword: "ChangedSecure456!",
  }, {mustChangePassword: true}));
  assert.equal((await getAuth().getUser(created.uid)).customClaims.mustChangePassword, false);
  assert.equal((await getFirestore().collection("usuarios").doc(created.uid).get()).data().mustChangePassword, false);
  await users.setUserActive(request("admin-backend", "admin", "site-a", {uid: created.uid, active: false}));
  assert.equal((await getAuth().getUser(created.uid)).disabled, true);
  await users.deleteUser(request("admin-backend", "admin", "site-a", {
    uid: created.uid,
    confirmUid: created.uid,
  }));
  await assert.rejects(getAuth().getUser(created.uid), (error) => error.code === "auth/user-not-found");
  assert.equal((await getFirestore().collection("usuarios").doc(created.uid).get()).exists, false);
});

test("el scheduler materializa EXPIRED y registra auditoría", async () => {
  const ref = getFirestore().collection("incidentes").doc(`expired-${Date.now()}`);
  const now = Date.now();
  await ref.set({
    schemaVersion: 2,
    nivel: "1",
    sedeId: "site-a",
    estado: "NOTIFIED",
    createdAt: new Date(now - 120_000),
    expiresAt: new Date(now - 1_000),
  });
  await maintenance.expireIncidents();
  const stored = (await ref.get()).data();
  assert.equal(stored.estado, "EXPIRED");
  assert.ok(stored.retentionDeleteAt);
  const events = await ref.collection("eventos").where("type", "==", "EXPIRED").get();
  assert.equal(events.size, 1);
});
