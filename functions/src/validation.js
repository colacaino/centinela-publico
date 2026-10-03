"use strict";

const crypto = require("node:crypto");
const {HttpsError} = require("firebase-functions/v2/https");

const ID_PATTERN = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$/;
const IDEMPOTENCY_PATTERN = /^[a-zA-Z0-9][a-zA-Z0-9._:-]{7,127}$/;

function requiredString(value, field, maxLength = 120) {
  const normalized = String(value || "").trim();
  if (!normalized || normalized.length > maxLength) {
    throw new HttpsError("invalid-argument", `${field} es obligatorio o excede el largo permitido.`);
  }
  return normalized;
}

function optionalString(value, field, maxLength = 120) {
  if (value === null || value === undefined || value === "") return null;
  return requiredString(value, field, maxLength);
}

function safeId(value, field) {
  const normalized = requiredString(value, field, 64);
  if (!ID_PATTERN.test(normalized)) {
    throw new HttpsError("invalid-argument", `${field} contiene caracteres no permitidos.`);
  }
  return normalized;
}

function idempotencyKey(value) {
  const normalized = requiredString(value, "idempotencyKey", 128);
  if (!IDEMPOTENCY_PATTERN.test(normalized)) {
    throw new HttpsError("invalid-argument", "idempotencyKey no tiene un formato válido.");
  }
  return normalized;
}

function email(value) {
  const normalized = requiredString(value, "email", 254).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(normalized)) {
    throw new HttpsError("invalid-argument", "El correo no es válido.");
  }
  return normalized;
}

function sha256(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function requestFingerprint(value) {
  return sha256(JSON.stringify(value));
}

module.exports = {
  ID_PATTERN,
  IDEMPOTENCY_PATTERN,
  requiredString,
  optionalString,
  safeId,
  idempotencyKey,
  email,
  sha256,
  requestFingerprint,
};
