"use strict";

const {HttpsError} = require("firebase-functions/v2/https");
const {ROLES} = require("./constants");

function principal(request, allowedRoles = ROLES) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  const token = request.auth.token || {};
  const role = String(token.role || "");
  const siteId = String(token.sedeId || "");
  if (token.active !== true || !ROLES.includes(role) || !siteId) {
    throw new HttpsError("permission-denied", "La cuenta no tiene autorización activa.");
  }
  if (token.mustChangePassword === true) {
    throw new HttpsError("failed-precondition", "Debes cambiar la contraseña temporal antes de continuar.");
  }
  if (!allowedRoles.includes(role)) {
    throw new HttpsError("permission-denied", "Tu rol no permite esta operación.");
  }
  return {
    uid: request.auth.uid,
    role,
    siteId,
    name: String(token.name || token.email || "Usuario").slice(0, 120),
  };
}

function requireSameSite(actor, resource) {
  if (!resource || resource.sedeId !== actor.siteId) {
    throw new HttpsError("permission-denied", "El recurso pertenece a otra sede.");
  }
}

module.exports = {principal, requireSameSite};
