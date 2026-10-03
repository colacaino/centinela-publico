"use strict";

const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");

const values = new Map(process.argv.slice(2).map((arg) => {
  const [key, ...value] = arg.replace(/^--/, "").split("=");
  return [key, value.join("=")];
}));
const projectId = values.get("project");
const uid = values.get("uid");
const siteId = values.get("site-id");
const confirm = values.get("confirm");

if (!projectId || !uid || !siteId || confirm !== `${projectId}:${uid}`) {
  console.error("Uso: node scripts/bootstrap_admin.js --project=ID --uid=UID --site-id=SEDE --confirm=ID:UID");
  process.exitCode = 2;
  return;
}

initializeApp({credential: applicationDefault(), projectId});
async function main() {
  const user = await getAuth().getUser(uid);
  await getAuth().setCustomUserClaims(uid, {
    role: "admin", sedeId: siteId, active: true, mustChangePassword: false,
  });
  await getFirestore().collection("usuarios").doc(uid).set({
    schemaVersion: 2,
    email: user.email || null,
    nombre: user.displayName || user.email || "Administrador",
    role: "admin",
    sedeId: siteId,
    active: true,
    mustChangePassword: false,
    updatedAt: Timestamp.now(),
    bootstrappedAt: Timestamp.now(),
  }, {merge: true});
  await getAuth().revokeRefreshTokens(uid);
  console.log(`Administrador preparado: ${uid}. Debe volver a iniciar sesión para obtener claims.`);
}
main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
