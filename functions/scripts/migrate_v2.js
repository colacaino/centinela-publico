"use strict";

// Migración deliberadamente conservadora: siempre es dry-run salvo --apply.
// Requiere Application Default Credentials fuera del repositorio.
const {initializeApp, applicationDefault} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const crypto = require("node:crypto");

const args = new Map(process.argv.slice(2).map((arg) => {
  const [key, ...rest] = arg.replace(/^--/, "").split("=");
  return [key, rest.length ? rest.join("=") : true];
}));
const apply = args.get("apply") === true;
const projectId = String(args.get("project") || process.env.GCLOUD_PROJECT || "");
const defaultSiteId = String(args.get("default-site-id") || "");
const migrateAlerts = args.get("migrate-alerts") === true;
const validId = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/;

if (!projectId || !validId.test(defaultSiteId)) {
  console.error("Uso: node scripts/migrate_v2.js --project=ID --default-site-id=SEDE [--migrate-alerts] [--apply]");
  process.exitCode = 2;
  return;
}

initializeApp({credential: applicationDefault(), projectId});
const db = getFirestore();
const auth = getAuth();

function normalizeRole(data) {
  const raw = String(data.role || data.rol || "").trim().toLowerCase();
  const aliases = {"dirección": "direccion", direccion: "direccion", profesor: "docente"};
  const role = aliases[raw] || raw;
  return ["docente", "inspector", "direccion", "admin"].includes(role) ? role : null;
}

function timestampFrom(data) {
  const candidate = data.createdAt || data.timestamp;
  return candidate && typeof candidate.toMillis === "function" ? candidate : Timestamp.now();
}

function shortHash(value) {
  return crypto.createHash("sha256").update(value).digest("hex").slice(0, 24);
}

async function migrateUsers() {
  const users = await db.collection("usuarios").get();
  const actions = [];
  for (const user of users.docs) {
    const data = user.data();
    const role = normalizeRole(data);
    if (!role) {
      actions.push({uid: user.id, action: "SKIP_INVALID_ROLE", legacyRole: data.role || data.rol || null});
      continue;
    }
    const siteId = validId.test(String(data.sedeId || "")) ? data.sedeId : defaultSiteId;
    actions.push({uid: user.id, action: "UPSERT_PROFILE_AND_CLAIMS", role, siteId});
    if (!apply) continue;
    const active = data.active !== false;
    await auth.setCustomUserClaims(user.id, {role, sedeId: siteId, active, mustChangePassword: false});
    await user.ref.set({
      schemaVersion: 2,
      role,
      sedeId: siteId,
      active,
      mustChangePassword: false,
      nombre: String(data.nombre || data.name || data.email || "Usuario").slice(0, 120),
      updatedAt: Timestamp.now(),
      migratedAt: Timestamp.now(),
    }, {merge: true});
  }
  return actions;
}

async function migrateLegacyAlerts() {
  if (!migrateAlerts) return [];
  const alerts = await db.collection("alertas").get();
  const actions = [];
  for (const alert of alerts.docs) {
    const data = alert.data();
    const level = String(data.nivel || "");
    if (!["1", "2", "3"].includes(level)) {
      actions.push({legacyId: alert.id, action: "SKIP_INVALID_LEVEL"});
      continue;
    }
    const incidentId = `legacy_${shortHash(alert.id)}`;
    actions.push({legacyId: alert.id, incidentId, action: "CREATE_EXPIRED_ARCHIVE"});
    if (!apply) continue;
    const createdAt = timestampFrom(data);
    const incident = {
      schemaVersion: 2,
      legacySourceId: alert.id,
      nivel: level,
      etiqueta: String(data.etiqueta || "Alerta legada").slice(0, 120),
      sedeId: validId.test(String(data.sedeId || "")) ? data.sedeId : defaultSiteId,
      salaId: null,
      salaNombreSnapshot: String(data.sala || "Ubicación histórica no normalizada").slice(0, 120),
      origen: "legacy_migration",
      emisorUid: data.emisor || null,
      nombreEmisorSnapshot: String(data.nombreEmisor || "Usuario legado").slice(0, 120),
      dispositivoId: null,
      simulacro: false,
      estado: "EXPIRED",
      createdAt,
      expiresAt: createdAt,
      retentionDeleteAt: null,
      fanoutStatus: "MIGRATED_NO_FANOUT",
      fanoutAttempts: 0,
      deliveredCount: 0,
      failedCount: 0,
      requestFingerprint: shortHash(`legacy:${alert.id}`),
      updatedAt: Timestamp.now(),
      migratedAt: Timestamp.now(),
    };
    await db.collection("incidentes").doc(incidentId).set(incident, {merge: false});
  }
  return actions;
}

async function main() {
  console.log(JSON.stringify({
    mode: apply ? "APPLY" : "DRY_RUN",
    projectId,
    defaultSiteId,
    migrateAlerts,
    credentialMode: useFirebaseCliAuth ? "FIREBASE_CLI_LOCAL" : "ADC",
  }));
  if (apply && args.get("confirm") !== projectId) {
    throw new Error("Para aplicar agrega --confirm=<projectId> exactamente.");
  }
  if (apply) {
    await db.collection("sedes").doc(defaultSiteId).set({
      sedeId: defaultSiteId,
      nombre: String(args.get("site-name") || defaultSiteId).slice(0, 120),
      active: true,
      schemaVersion: 2,
      updatedAt: Timestamp.now(),
    }, {merge: true});
  }
  const users = await migrateUsers();
  const alerts = await migrateLegacyAlerts();
  console.log(JSON.stringify({users, alerts}, null, 2));
  console.log(apply ? "Migración aplicada. Verifica claims, perfiles y conteos antes de continuar." : "Dry-run: no se escribió ningún dato.");
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
