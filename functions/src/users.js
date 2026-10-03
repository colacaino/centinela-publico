"use strict";

const {getAuth} = require("firebase-admin/auth");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {HttpsError} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const {ROLES} = require("./constants");
const {principal, requireSameSite} = require("./authz");
const {requiredString, safeId, email} = require("./validation");

function validateRole(value) {
  const role = String(value || "");
  if (!ROLES.includes(role)) {
    throw new HttpsError("invalid-argument", "El rol solicitado no existe.");
  }
  return role;
}

function password(value) {
  const result = String(value || "");
  if (result.length < 12 || result.length > 128 ||
      !/[a-z]/.test(result) || !/[A-Z]/.test(result) || !/[0-9]/.test(result)) {
    throw new HttpsError(
        "invalid-argument",
        "La contraseña temporal debe tener 12–128 caracteres, mayúscula, minúscula y número.",
    );
  }
  return result;
}

async function targetProfile(db, uid) {
  const ref = db.collection("usuarios").doc(uid);
  const snapshot = await ref.get();
  if (!snapshot.exists) throw new HttpsError("not-found", "Usuario no encontrado.");
  return {ref, data: snapshot.data()};
}

async function createUser(request) {
  const actor = principal(request, ["admin"]);
  const data = request.data || {};
  const normalizedEmail = email(data.email);
  const displayName = requiredString(data.nombre, "nombre", 120);
  const role = validateRole(data.role);
  const temporaryPassword = password(data.temporaryPassword);
  const auth = getAuth();
  const db = getFirestore();
  let created = null;
  try {
    created = await auth.createUser({
      email: normalizedEmail,
      password: temporaryPassword,
      displayName,
      disabled: false,
      emailVerified: false,
    });
    const claims = {role, sedeId: actor.siteId, active: true, mustChangePassword: true};
    await auth.setCustomUserClaims(created.uid, claims);
    await db.collection("usuarios").doc(created.uid).create({
      schemaVersion: 2,
      email: normalizedEmail,
      nombre: displayName,
      role,
      sedeId: actor.siteId,
      active: true,
      mustChangePassword: true,
      createdAt: Timestamp.now(),
      createdBy: actor.uid,
      updatedAt: Timestamp.now(),
    });
    logger.info("user_created", {actorUid: actor.uid, targetUid: created.uid, siteId: actor.siteId, role});
    return {uid: created.uid};
  } catch (error) {
    if (created) {
      try {
        await auth.deleteUser(created.uid);
      } catch (rollbackError) {
        logger.error("user_create_rollback_failed", {targetUid: created.uid, code: rollbackError.code});
      }
    }
    if (error instanceof HttpsError) throw error;
    if (String(error.code || "").startsWith("auth/")) {
      throw new HttpsError("already-exists", "No fue posible crear la cuenta; verifica el correo.");
    }
    logger.error("user_create_failed", {code: error.code});
    throw new HttpsError("internal", "No fue posible crear la cuenta.");
  }
}

async function updateUser(request) {
  const actor = principal(request, ["admin"]);
  const data = request.data || {};
  const uid = safeId(data.uid, "uid");
  const displayName = requiredString(data.nombre, "nombre", 120);
  const role = validateRole(data.role);
  const db = getFirestore();
  const target = await targetProfile(db, uid);
  requireSameSite(actor, target.data);
  await getAuth().updateUser(uid, {displayName});
  await getAuth().setCustomUserClaims(uid, {
    role,
    sedeId: actor.siteId,
    active: target.data.active === true,
    mustChangePassword: target.data.mustChangePassword === true,
  });
  await target.ref.update({nombre: displayName, role, updatedAt: Timestamp.now(), updatedBy: actor.uid});
  await getAuth().revokeRefreshTokens(uid);
  logger.info("user_updated", {actorUid: actor.uid, targetUid: uid, siteId: actor.siteId, role});
  return {uid};
}

async function setUserActive(request) {
  const actor = principal(request, ["admin"]);
  const data = request.data || {};
  const uid = safeId(data.uid, "uid");
  const active = data.active === true;
  if (uid === actor.uid && !active) {
    throw new HttpsError("failed-precondition", "No puedes desactivar tu propia cuenta.");
  }
  const db = getFirestore();
  const target = await targetProfile(db, uid);
  requireSameSite(actor, target.data);
  await getAuth().updateUser(uid, {disabled: !active});
  await getAuth().setCustomUserClaims(uid, {
    role: target.data.role,
    sedeId: actor.siteId,
    active,
    mustChangePassword: target.data.mustChangePassword === true,
  });
  await target.ref.update({active, updatedAt: Timestamp.now(), updatedBy: actor.uid});
  await getAuth().revokeRefreshTokens(uid);
  logger.info("user_activation_changed", {actorUid: actor.uid, targetUid: uid, siteId: actor.siteId, active});
  return {uid, active};
}

async function deleteUser(request) {
  const actor = principal(request, ["admin"]);
  const data = request.data || {};
  const uid = safeId(data.uid, "uid");
  const confirmation = safeId(data.confirmUid, "confirmUid");
  if (uid !== confirmation) {
    throw new HttpsError("invalid-argument", "La confirmación no coincide con el usuario.");
  }
  if (uid === actor.uid) {
    throw new HttpsError("failed-precondition", "No puedes eliminar tu propia cuenta.");
  }
  const db = getFirestore();
  const target = await targetProfile(db, uid);
  requireSameSite(actor, target.data);
  await getAuth().deleteUser(uid);
  await db.recursiveDelete(target.ref);
  logger.info("user_deleted", {actorUid: actor.uid, targetUid: uid, siteId: actor.siteId});
  return {uid, deleted: true};
}

async function changeInitialPassword(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  const token = request.auth.token || {};
  if (token.active !== true || token.mustChangePassword !== true ||
      !ROLES.includes(String(token.role || "")) || !token.sedeId) {
    throw new HttpsError("failed-precondition", "La cuenta no requiere un cambio inicial.");
  }
  const newPassword = password(request.data && request.data.newPassword);
  const uid = request.auth.uid;
  const db = getFirestore();
  const target = await targetProfile(db, uid);
  if (target.data.sedeId !== token.sedeId || target.data.mustChangePassword !== true) {
    throw new HttpsError("permission-denied", "El perfil no coincide con la sesión.");
  }
  await getAuth().updateUser(uid, {password: newPassword});
  await getAuth().setCustomUserClaims(uid, {
    role: token.role,
    sedeId: token.sedeId,
    active: true,
    mustChangePassword: false,
  });
  await target.ref.update({
    mustChangePassword: false,
    passwordChangedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await getAuth().revokeRefreshTokens(uid);
  logger.info("initial_password_changed", {targetUid: uid, siteId: token.sedeId});
  return {changed: true, signInAgain: true};
}

module.exports = {
  createUser,
  updateUser,
  setUserActive,
  deleteUser,
  changeInitialPassword,
  validateRole,
  password,
};
