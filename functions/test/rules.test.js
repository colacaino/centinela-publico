"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, collection, getDocs, query, where} = require("firebase/firestore");

let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId: "demo-centinela",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "..", "..", "firestore.rules"), "utf8"),
    },
  });
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "usuarios/u-docente"), {nombre: "Docente", role: "docente", sedeId: "site-a", active: true});
    await setDoc(doc(db, "usuarios/u-admin-b"), {nombre: "Admin B", role: "admin", sedeId: "site-b", active: true});
    await setDoc(doc(db, "usuarios/u-inspector"), {nombre: "Inspector", role: "inspector", sedeId: "site-a", active: true});
    await setDoc(doc(db, "usuarios/u-docente/instalaciones/install-a"), {uid: "u-docente", sedeId: "site-a", active: true});
    await setDoc(doc(db, "sedes/site-a"), {nombre: "Sede A", sedeId: "site-a"});
    await setDoc(doc(db, "sedes/site-a/salas/room-1"), {nombre: "Sala 1", active: true});
    await setDoc(doc(db, "incidentes/inc-level-1"), {
      nivel: "1", sedeId: "site-a", emisorUid: "u-docente", estado: "NOTIFIED",
    });
    await setDoc(doc(db, "incidentes/inc-level-2"), {
      nivel: "2", sedeId: "site-a", emisorUid: "someone", estado: "NOTIFIED",
    });
    await setDoc(doc(db, "incidentes/inc-site-b"), {
      nivel: "3", sedeId: "site-b", emisorUid: "someone", estado: "NOTIFIED",
    });
    await setDoc(doc(db, "alertas/legacy"), {sede: "site-a", nivel: "3"});
  });
});

test.after(async () => {
  await environment.cleanup();
});

function authenticated(uid, role, siteId = "site-a", active = true) {
  return environment.authenticatedContext(uid, {role, sedeId: siteId, active}).firestore();
}

test("niega todo a sesiones anónimas o inactivas", async () => {
  const anonymous = environment.unauthenticatedContext().firestore();
  const inactive = authenticated("u-inspector", "inspector", "site-a", false);
  await assertFails(getDoc(doc(anonymous, "incidentes/inc-level-1")));
  await assertFails(getDoc(doc(inactive, "incidentes/inc-level-1")));
});

test("ningún cliente puede escribir incidentes ni el legado", async () => {
  const admin = authenticated("u-admin", "admin");
  await assertFails(setDoc(doc(admin, "incidentes/attack"), {nivel: "3", sedeId: "site-a"}));
  await assertFails(setDoc(doc(admin, "alertas/attack"), {nivel: "3", sede: "site-a"}));
});

test("el emisor puede leer su incidente y no incidentes ajenos a su rol", async () => {
  const teacher = authenticated("u-docente", "docente");
  await assertSucceeds(getDoc(doc(teacher, "incidentes/inc-level-1")));
  await assertFails(getDoc(doc(teacher, "incidentes/inc-level-2")));
});

test("la matriz de nivel se aplica y la sede aísla incluso al administrador", async () => {
  const direction = authenticated("u-direction", "direccion");
  const inspector = authenticated("u-inspector", "inspector");
  const adminA = authenticated("u-admin-a", "admin");
  await assertFails(getDoc(doc(direction, "incidentes/inc-level-1")));
  await assertSucceeds(getDoc(doc(direction, "incidentes/inc-level-2")));
  await assertSucceeds(getDoc(doc(inspector, "incidentes/inc-level-1")));
  await assertFails(getDoc(doc(adminA, "incidentes/inc-site-b")));
});

test("un usuario lee solo su instalación y un admin lista solo su sede", async () => {
  const teacher = authenticated("u-docente", "docente");
  const other = authenticated("u-other", "docente");
  const adminA = authenticated("u-admin-a", "admin");
  await assertSucceeds(getDoc(doc(teacher, "usuarios/u-docente/instalaciones/install-a")));
  await assertFails(getDoc(doc(other, "usuarios/u-docente/instalaciones/install-a")));
  const sameSite = query(collection(adminA, "usuarios"), where("sedeId", "==", "site-a"));
  await assertSucceeds(getDocs(sameSite));
  assert.equal((await getDocs(sameSite)).size, 2);
  await assertFails(getDoc(doc(adminA, "usuarios/u-admin-b")));
});

test("salas solo son visibles en la sede declarada en claims", async () => {
  const siteA = authenticated("u-docente", "docente", "site-a");
  const siteB = authenticated("u-admin-b", "admin", "site-b");
  await assertSucceeds(getDoc(doc(siteA, "sedes/site-a/salas/room-1")));
  await assertFails(getDoc(doc(siteB, "sedes/site-a/salas/room-1")));
});
